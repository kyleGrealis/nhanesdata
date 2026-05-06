# =============================================================================
# validate_dataset.R
#
# Per-dataset validation engine for the NHANES harmonization audit.
# Fetches codebooks for EVERY cycle (not just newest), compares variable
# mappings across cycles, classifies drift, and cross-checks pipeline output.
#
# All CDC API results are cached locally in inst/cache/ to avoid rate limiting.
#
# Usage:
#   source("inst/scripts/validate_dataset.R")
#   report <- validate_dataset("demo")
#   report <- validate_dataset("diq")
#
# The report object contains:
#   $codebook_inventory  - per-cycle codebook availability
#   $variable_comparison - per-variable drift classification
#   $pipeline_check      - comparison of pipeline output vs codebooks
#   $summary             - human-readable summary
# =============================================================================

library(dplyr)
library(stringr)
library(tibble)

# ---------------------------------------------------------------------------
# Configuration: cycle suffixes and years (matches pull_nhanes.R)
# ---------------------------------------------------------------------------
CYCLE_SUFFIXES <- c("", LETTERS[2:10], LETTERS[12:16])
CYCLE_YEARS <- c(seq(1999, 2017, by = 2), seq(2021, 2029, by = 2))
CACHE_DIR_CODEBOOKS <- "inst/cache/codebooks"
CACHE_DIR_DATA <- "inst/cache/data"

# Ensure cache directories exist
if (!dir.exists(CACHE_DIR_CODEBOOKS)) dir.create(CACHE_DIR_CODEBOOKS, recursive = TRUE)
if (!dir.exists(CACHE_DIR_DATA)) dir.create(CACHE_DIR_DATA, recursive = TRUE)

# ---------------------------------------------------------------------------
# Cache helpers
# ---------------------------------------------------------------------------

#' Build cache file path for a codebook or data file
.cache_path <- function(type, table_code) {
  dir <- if (type == "codebook") CACHE_DIR_CODEBOOKS else CACHE_DIR_DATA
  file.path(dir, paste0(table_code, ".rds"))
}

#' Fetch codebook (nhanesTranslate) with caching
.fetch_codebook_cached <- function(table_code) {
  cache_file <- .cache_path("codebook", table_code)

  if (file.exists(cache_file)) {
    return(readRDS(cache_file))
  }

  result <- tryCatch(
    suppressMessages(suppressWarnings(
      nhanesA::nhanesTranslate(table_code)
    )),
    error = function(e) NULL
  )

  # Cache even NULL results (means no codebook available for this cycle)
  # Use a sentinel value to distinguish "cached NULL" from "not cached"
  saveRDS(if (is.null(result)) list(.no_codebook = TRUE) else result, cache_file)
  result
}

#' Fetch raw data (nhanes) with caching
.fetch_data_cached <- function(table_code) {
  cache_file <- .cache_path("data", table_code)

  if (file.exists(cache_file)) {
    cached <- readRDS(cache_file)
    # Check sentinel for "table doesn't exist"
    if (is.list(cached) && !is.data.frame(cached) && isTRUE(cached$.no_data)) {
      return(NULL)
    }
    return(cached)
  }

  result <- tryCatch(
    nhanesA::nhanes(table_code),
    error = function(e) {
      message(sprintf("  Error fetching %s: %s", table_code, e$message))
      NULL
    }
  )

  saveRDS(if (is.null(result)) list(.no_data = TRUE) else result, cache_file)
  result
}

# ---------------------------------------------------------------------------
# Step 1: Per-Cycle Codebook Inventory
# ---------------------------------------------------------------------------

#' Fetch codebooks for every cycle of a dataset
#'
#' @param nhanes_table Character. Base table name (e.g., "DEMO", "DIQ")
#' @return A named list: cycle suffix -> codebook (list of translation tables)
#'         Elements are NULL where no codebook was available.
codebook_inventory <- function(nhanes_table) {
  nhanes_table <- toupper(nhanes_table)
  message(sprintf("\n=== Codebook Inventory: %s ===", nhanes_table))

  inventory <- list()

  for (i in seq_along(CYCLE_SUFFIXES)) {
    suffix <- CYCLE_SUFFIXES[i]
    year <- CYCLE_YEARS[i]
    table_code <- if (suffix == "") nhanes_table else paste0(nhanes_table, "_", suffix)

    message(sprintf("  [%d-%d] %s ... ", year, year + 1, table_code), appendLF = FALSE)

    cb <- .fetch_codebook_cached(table_code)

    if (is.null(cb) || (is.list(cb) && isTRUE(cb$.no_codebook))) {
      message("no codebook")
      inventory[[table_code]] <- NULL
    } else {
      n_vars <- length(cb)
      message(sprintf("%d variables translated", n_vars))
      inventory[[table_code]] <- cb
    }
  }

  # Summary
  available <- sum(!sapply(inventory, is.null))
  message(sprintf(
    "\nCodebook summary: %d/%d cycles have codebooks",
    available, length(inventory)
  ))

  inventory
}

# ---------------------------------------------------------------------------
# Step 2: Cross-Cycle Variable Comparison
# ---------------------------------------------------------------------------

#' Compare variable code-to-label mappings across cycles
#'
#' @param inventory Named list from codebook_inventory()
#' @return A tibble with columns: variable, classification, details
compare_variables <- function(inventory) {
  # Collect all variable names across all cycles that have codebooks
  available <- inventory[!sapply(inventory, is.null)]

  if (length(available) == 0) {
    message("  No codebooks available - cannot compare variables.")
    return(tibble(
      variable = character(),
      classification = character(),
      n_cycles = integer(),
      details = character()
    ))
  }

  all_vars <- unique(unlist(lapply(available, names)))
  message(sprintf(
    "\n=== Cross-Cycle Comparison: %d variables across %d cycles ===",
    length(all_vars), length(available)
  ))

  results <- list()

  for (var_name in all_vars) {
    # Gather this variable's translation table from each cycle
    var_tables <- list()
    for (cycle_name in names(available)) {
      cb <- available[[cycle_name]]
      if (var_name %in% names(cb)) {
        tt <- cb[[var_name]]
        # Normalize: keep Code.or.Value and Value.Description
        if (!is.null(tt) && nrow(tt) > 0) {
          tt <- tt[, c("Code.or.Value", "Value.Description"), drop = FALSE]
          # Remove the "." (missing) row for comparison
          tt <- tt[tt$Code.or.Value != ".", , drop = FALSE]
          var_tables[[cycle_name]] <- tt
        }
      }
    }

    if (length(var_tables) == 0) next

    # Check if it's a continuous variable (has "Range of Values")
    is_continuous <- any(sapply(var_tables, function(tt) {
      any(grepl("Range of Values", tt$Value.Description, fixed = TRUE))
    }))

    if (is_continuous) {
      results[[var_name]] <- tibble(
        variable = var_name,
        classification = "continuous",
        n_cycles = length(var_tables),
        details = "Continuous variable (Range of Values); skip label comparison"
      )
      next
    }

    # For categorical variables, compare code-to-label mappings
    if (length(var_tables) == 1) {
      results[[var_name]] <- tibble(
        variable = var_name,
        classification = "single_cycle",
        n_cycles = 1L,
        details = sprintf("Only in %s", names(var_tables)[1])
      )
      next
    }

    # Build a unified lookup: code -> label per cycle
    classification <- .classify_variable_drift(var_name, var_tables)
    results[[var_name]] <- classification
  }

  result_df <- bind_rows(results)

  # Summary counts
  if (nrow(result_df) > 0) {
    counts <- result_df |>
      count(classification) |>
      arrange(desc(n))
    message("\nDrift classification summary:")
    for (i in seq_len(nrow(counts))) {
      message(sprintf("  %s: %d variables", counts$classification[i], counts$n[i]))
    }
  }

  result_df
}

#' Classify drift for a single variable across cycles
#'
#' @param var_name Character. Variable name
#' @param var_tables Named list of data frames (cycle -> translation table)
#' @return A single-row tibble with classification
.classify_variable_drift <- function(var_name, var_tables) {
  # Build a master table: code, label, cycle
  master <- list()
  for (cycle_name in names(var_tables)) {
    tt <- var_tables[[cycle_name]]
    master[[cycle_name]] <- tibble(
      code = as.character(tt$Code.or.Value),
      label = tt$Value.Description,
      cycle = cycle_name
    )
  }
  master_df <- bind_rows(master)

  # Get unique code-label pairs per cycle
  code_labels_by_cycle <- split(master_df, master_df$cycle)

  # Check 1: Are all code-label pairs identical across cycles?
  # Normalize: sort by code within each cycle, then compare
  normalized <- lapply(code_labels_by_cycle, function(df) {
    df |> arrange(code) |> select(code, label)
  })

  # Compare all cycles to the first
  reference <- normalized[[1]]
  all_identical <- TRUE
  cosmetic_only <- TRUE
  drift_details <- character()

  for (i in seq_along(normalized)) {
    current <- normalized[[i]]
    cycle_name <- names(normalized)[i]

    # Check if code sets match
    if (!setequal(reference$code, current$code)) {
      all_identical <- FALSE
      cosmetic_only <- FALSE

      added_codes <- setdiff(current$code, reference$code)
      removed_codes <- setdiff(reference$code, current$code)

      if (length(added_codes) > 0) {
        added_labels <- current$label[current$code %in% added_codes]
        drift_details <- c(drift_details, sprintf(
          "%s added codes: %s",
          cycle_name,
          paste(sprintf("%s='%s'", added_codes, added_labels), collapse = ", ")
        ))
      }
      if (length(removed_codes) > 0) {
        drift_details <- c(drift_details, sprintf(
          "%s missing codes: %s",
          cycle_name,
          paste(removed_codes, collapse = ", ")
        ))
      }
    }

    # For shared codes, check if labels match
    shared_codes <- intersect(reference$code, current$code)
    for (code in shared_codes) {
      ref_label <- reference$label[reference$code == code]
      cur_label <- current$label[current$code == code]

      # Handle duplicate codes (take first match)
      if (length(ref_label) > 1) ref_label <- ref_label[1]
      if (length(cur_label) > 1) cur_label <- cur_label[1]

      if (length(ref_label) > 0 && length(cur_label) > 0) {
        if (ref_label != cur_label) {
          all_identical <- FALSE
          # Is it just capitalization/punctuation?
          if (tolower(trimws(ref_label)) == tolower(trimws(cur_label))) {
            # Cosmetic
            drift_details <- c(drift_details, sprintf(
              "Code %s: '%s' vs '%s' (cosmetic)",
              code, ref_label, cur_label
            ))
          } else {
            cosmetic_only <- FALSE
            drift_details <- c(drift_details, sprintf(
              "Code %s: '%s' (%s) vs '%s' (%s) *** SEMANTIC ***",
              code, ref_label, names(normalized)[1],
              cur_label, cycle_name
            ))
          }
        }
      }
    }
  }

  if (all_identical) {
    classification <- "stable"
    details <- "Identical across all cycles"
  } else if (cosmetic_only) {
    classification <- "cosmetic_drift"
    details <- paste(drift_details, collapse = "; ")
  } else {
    classification <- "semantic_drift"
    details <- paste(drift_details, collapse = "; ")
  }

  tibble(
    variable = var_name,
    classification = classification,
    n_cycles = length(var_tables),
    details = details
  )
}

# ---------------------------------------------------------------------------
# Step 3: Pipeline Output Verification
# ---------------------------------------------------------------------------

#' Verify pull_nhanes() output against per-cycle codebooks
#'
#' @param nhanes_table Character. Base table name
#' @param inventory Named list from codebook_inventory()
#' @param comparison Tibble from compare_variables()
#' @return A list with verification results
verify_pipeline <- function(nhanes_table, inventory, comparison) {
  nhanes_table <- toupper(nhanes_table)
  message(sprintf("\n=== Pipeline Verification: %s ===", nhanes_table))

  # Source pull_nhanes
  if (!exists("pull_nhanes", mode = "function")) {
    source("inst/scripts/pull_nhanes.R")
  }

  # Pull the merged data
  message("  Running pull_nhanes()...")
  merged <- tryCatch(
    pull_nhanes(tolower(nhanes_table), save = FALSE),
    error = function(e) {
      message(sprintf("  ERROR: %s", e$message))
      NULL
    }
  )

  if (is.null(merged) || nrow(merged) == 0) {
    return(list(
      status = "PULL_FAILED",
      message = "pull_nhanes() returned NULL or empty"
    ))
  }

  message(sprintf("  Merged data: %s rows, %d columns",
    scales::comma(nrow(merged)), ncol(merged)
  ))

  # Get variables with semantic drift
  semantic_vars <- comparison |>
    filter(classification == "semantic_drift")

  # Get variables with cosmetic drift
  cosmetic_vars <- comparison |>
    filter(classification == "cosmetic_drift")

  # Cross-check: for each cycle's data, verify categorical values match codebook
  issues <- list()
  available_cbs <- inventory[!sapply(inventory, is.null)]

  for (cycle_name in names(available_cbs)) {
    cb <- available_cbs[[cycle_name]]
    # Determine the year for this cycle
    suffix <- sub(paste0("^", nhanes_table, "_?"), "", cycle_name)
    if (suffix == nhanes_table || suffix == "") {
      cycle_year <- 1999L
    } else {
      idx <- match(suffix, CYCLE_SUFFIXES)
      if (is.na(idx)) next
      cycle_year <- CYCLE_YEARS[idx]
    }

    cycle_rows <- merged |> filter(year == cycle_year)
    if (nrow(cycle_rows) == 0) next

    for (var_name in names(cb)) {
      var_lower <- tolower(var_name)
      if (!(var_lower %in% names(cycle_rows))) next

      tt <- cb[[var_name]]
      if (is.null(tt) || nrow(tt) == 0) next

      # Skip continuous variables
      has_range <- any(grepl("Range of Values", tt$Value.Description, fixed = TRUE))
      if (has_range) next

      # Get expected labels from this cycle's codebook
      tt_clean <- tt[tt$Code.or.Value != ".", , drop = FALSE]
      expected_labels <- tt_clean$Value.Description
      expected_codes <- tt_clean$Code.or.Value

      # Get actual values in the merged data for this cycle
      actual_values <- unique(cycle_rows[[var_lower]])
      actual_values <- actual_values[!is.na(actual_values)]

      if (length(actual_values) == 0) next

      # Check if actual values are labels (good) or raw codes (bad)
      # or something unexpected
      values_are_labels <- all(actual_values %in% expected_labels)
      values_are_codes <- all(actual_values %in% expected_codes)

      if (!values_are_labels && !values_are_codes) {
        # Some values don't match either labels or codes
        unexpected <- setdiff(actual_values, c(expected_labels, expected_codes))
        if (length(unexpected) > 0 && length(unexpected) <= 20) {
          issues[[paste0(cycle_name, ":", var_name)]] <- list(
            cycle = cycle_name,
            year = cycle_year,
            variable = var_name,
            type = "unexpected_values",
            unexpected = unexpected,
            expected_labels = expected_labels,
            expected_codes = expected_codes
          )
        }
      }
    }
  }

  list(
    status = if (length(issues) == 0) "CLEAN" else "ISSUES_FOUND",
    n_rows = nrow(merged),
    n_cols = ncol(merged),
    n_cycles = length(unique(merged$year)),
    cycles = sort(unique(merged$year)),
    n_semantic_drift = nrow(semantic_vars),
    semantic_drift_vars = if (nrow(semantic_vars) > 0) semantic_vars else NULL,
    n_cosmetic_drift = nrow(cosmetic_vars),
    cosmetic_drift_vars = if (nrow(cosmetic_vars) > 0) cosmetic_vars else NULL,
    n_pipeline_issues = length(issues),
    pipeline_issues = if (length(issues) > 0) issues else NULL,
    merged_data = merged
  )
}

# ---------------------------------------------------------------------------
# Main validation function
# ---------------------------------------------------------------------------

#' Run full validation for a dataset
#'
#' @param nhanes_table Character. Base table name (e.g., "demo", "DIQ")
#' @return A list with: codebook_inventory, variable_comparison, pipeline_check, summary
validate_dataset <- function(nhanes_table) {
  nhanes_table <- toupper(nhanes_table)
  message(sprintf("\n%s", paste(rep("=", 70), collapse = "")))
  message(sprintf("VALIDATING: %s", nhanes_table))
  message(sprintf("%s\n", paste(rep("=", 70), collapse = "")))

  # Step 1: Codebook inventory
  inventory <- codebook_inventory(nhanes_table)

  # Step 2: Cross-cycle comparison
  comparison <- compare_variables(inventory)

  # Step 3: Pipeline verification
  pipeline <- verify_pipeline(nhanes_table, inventory, comparison)

  # Build summary
  summary_lines <- character()
  summary_lines <- c(summary_lines, sprintf("Dataset: %s", nhanes_table))
  summary_lines <- c(summary_lines, sprintf("Cycles with data: %d (%s)",
    pipeline$n_cycles,
    paste(pipeline$cycles, collapse = ", ")
  ))
  summary_lines <- c(summary_lines, sprintf("Total rows: %s", scales::comma(pipeline$n_rows)))
  summary_lines <- c(summary_lines, sprintf("Total columns: %d", pipeline$n_cols))

  codebooks_available <- sum(!sapply(inventory, is.null))
  summary_lines <- c(summary_lines, sprintf(
    "Codebooks available: %d/%d cycles",
    codebooks_available, length(inventory)
  ))

  if (nrow(comparison) > 0) {
    counts <- comparison |> count(classification)
    for (i in seq_len(nrow(counts))) {
      summary_lines <- c(summary_lines, sprintf(
        "  %s: %d variables", counts$classification[i], counts$n[i]
      ))
    }
  }

  if (pipeline$n_semantic_drift > 0) {
    summary_lines <- c(summary_lines, sprintf(
      "\n*** SEMANTIC DRIFT DETECTED: %d variables ***",
      pipeline$n_semantic_drift
    ))
  }

  if (pipeline$n_pipeline_issues > 0) {
    summary_lines <- c(summary_lines, sprintf(
      "\n*** PIPELINE ISSUES: %d variables with unexpected values ***",
      pipeline$n_pipeline_issues
    ))
  }

  summary_text <- paste(summary_lines, collapse = "\n")
  message(sprintf("\n--- Summary ---\n%s\n", summary_text))

  list(
    dataset = nhanes_table,
    codebook_inventory = inventory,
    variable_comparison = comparison,
    pipeline_check = pipeline,
    summary = summary_text
  )
}
