# =============================================================================
# compare_pipeline.R
#
# Compares the new pull_nhanes() output (with fixed type harmonization) against
# existing parquet files in data/raw/parquet/. Produces a markdown report
# documenting every difference: row counts, column changes, type changes, and
# value distribution changes.
#
# Usage:
#   Rscript inst/scripts/compare_pipeline.R
#   Rscript inst/scripts/compare_pipeline.R --datasets=bmx,demo,smq
#
# Output:
#   data/raw/comparison_report.md
#   data/raw/comparison_results.rds  (intermediate, for resuming)
# =============================================================================

library(arrow)
library(dplyr)
library(yaml)

devtools::load_all()

# ---------------------------------------------------------------------------
# Parse command-line arguments
# ---------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
filter_datasets <- NULL

for (arg in args) {
  if (grepl("^--datasets=", arg)) {
    filter_datasets <- unlist(strsplit(
      sub("^--datasets=", "", arg), ","
    ))
    message(sprintf(
      "Filtering to %d datasets: %s",
      length(filter_datasets),
      paste(filter_datasets, collapse = ", ")
    ))
  }
}

# ---------------------------------------------------------------------------
# Load dataset list from YAML
# ---------------------------------------------------------------------------
yml_path <- "inst/extdata/datasets.yml"
if (!file.exists(yml_path)) {
  stop("Cannot find ", yml_path, ". Run from package root directory.")
}

config <- yaml::read_yaml(yml_path)
all_datasets <- sapply(config$datasets, function(x) x$name)

if (!is.null(filter_datasets)) {
  all_datasets <- intersect(all_datasets, filter_datasets)
}

message(sprintf(
  "\n=== Pipeline Comparison: %d datasets ===\n",
  length(all_datasets)
))

# ---------------------------------------------------------------------------
# Resume support: load previous results if they exist
# ---------------------------------------------------------------------------
rds_path <- "data/raw/comparison_results.rds"
if (file.exists(rds_path) && is.null(filter_datasets)) {
  previous <- readRDS(rds_path)
  completed <- names(previous)
  message(sprintf(
    "Resuming: %d datasets already completed, %d remaining",
    length(completed),
    length(setdiff(all_datasets, completed))
  ))
} else {
  previous <- list()
  completed <- character(0)
}

# ---------------------------------------------------------------------------
# Compare one dataset: returns a list describing all differences
# ---------------------------------------------------------------------------
compare_dataset <- function(dataset_name) {
  parquet_path <- sprintf("data/raw/parquet/%s.parquet", dataset_name)
  has_baseline <- file.exists(parquet_path)

  # Pull new data with the fixed harmonization code
  new_data <- tryCatch(
    pull_nhanes(dataset_name, save = FALSE),
    error = function(e) {
      message(sprintf("  ERROR pulling %s: %s", dataset_name, e$message))
      NULL
    }
  )

  if (is.null(new_data)) {
    return(list(
      name = dataset_name,
      status = "PULL_FAILED",
      error = "pull_nhanes() returned NULL or errored"
    ))
  }

  if (!has_baseline) {
    return(list(
      name = dataset_name,
      status = "NEW",
      new_rows = nrow(new_data),
      new_cols = ncol(new_data),
      new_col_names = names(new_data),
      note = "No baseline parquet file (new dataset)"
    ))
  }

  # Load existing baseline
  old_data <- tryCatch(
    arrow::read_parquet(parquet_path),
    error = function(e) {
      message(sprintf(
        "  ERROR reading baseline %s: %s", parquet_path, e$message
      ))
      NULL
    }
  )

  if (is.null(old_data)) {
    return(list(
      name = dataset_name,
      status = "BASELINE_READ_FAILED",
      new_rows = nrow(new_data)
    ))
  }

  # --- Row count comparison ---
  row_diff <- nrow(new_data) - nrow(old_data)

  # --- Column comparison ---
  old_cols <- sort(names(old_data))
  new_cols <- sort(names(new_data))
  added_cols <- setdiff(new_cols, old_cols)
  removed_cols <- setdiff(old_cols, new_cols)
  shared_cols <- intersect(old_cols, new_cols)

  # --- Type comparison for shared columns ---
  type_changes <- list()
  for (col in shared_cols) {
    old_type <- class(old_data[[col]])[1]
    new_type <- class(new_data[[col]])[1]

    if (old_type != new_type) {
      # Sample unique values (capped at 20)
      old_vals <- tryCatch(
        {
          uv <- unique(old_data[[col]])
          uv <- uv[!is.na(uv)]
          if (length(uv) > 20) uv <- c(head(sort(uv), 20))
          as.character(uv)
        },
        error = function(e) "(error reading values)"
      )

      new_vals <- tryCatch(
        {
          uv <- unique(new_data[[col]])
          uv <- uv[!is.na(uv)]
          if (length(uv) > 20) uv <- c(head(sort(uv), 20))
          as.character(uv)
        },
        error = function(e) "(error reading values)"
      )

      type_changes[[col]] <- list(
        old_type = old_type,
        new_type = new_type,
        old_values = old_vals,
        new_values = new_vals
      )
    }
  }

  # --- Determine overall status ---
  is_identical <- (row_diff == 0) &&
    (length(added_cols) == 0) &&
    (length(removed_cols) == 0) &&
    (length(type_changes) == 0)

  list(
    name = dataset_name,
    status = if (is_identical) "IDENTICAL" else "CHANGED",
    old_rows = nrow(old_data),
    new_rows = nrow(new_data),
    row_diff = row_diff,
    old_col_count = length(old_cols),
    new_col_count = length(new_cols),
    added_cols = added_cols,
    removed_cols = removed_cols,
    type_changes = type_changes,
    type_change_count = length(type_changes)
  )
}

# ---------------------------------------------------------------------------
# Main loop: compare each dataset
# ---------------------------------------------------------------------------
results <- previous
total <- length(all_datasets)
start_time <- Sys.time()

for (i in seq_along(all_datasets)) {
  ds <- all_datasets[i]

  if (ds %in% completed) {
    message(sprintf("[%d/%d] %s - already completed, skipping", i, total, ds))
    next
  }

  ds_start <- Sys.time()
  message(sprintf(
    "[%d/%d] Comparing: %s ...",
    i, total, toupper(ds)
  ))

  result <- compare_dataset(ds)
  results[[ds]] <- result

  elapsed <- round(difftime(Sys.time(), ds_start, units = "secs"), 1)
  message(sprintf(
    "  -> %s (%s seconds)", result$status, elapsed
  ))

  # Save intermediate results after each dataset
  saveRDS(results, rds_path)
}

total_elapsed <- round(
  difftime(Sys.time(), start_time, units = "mins"), 1
)
message(sprintf(
  "\n=== Comparison complete: %d datasets in %s minutes ===",
  length(results), total_elapsed
))

# ---------------------------------------------------------------------------
# Generate markdown report
# ---------------------------------------------------------------------------
report_path <- "data/raw/comparison_report.md"

lines <- character(0)
add <- function(...) {
  lines <<- c(lines, paste0(...))
}

add("# Pipeline Comparison Report")
add("")
add(sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
add("")

# Summary counts
statuses <- sapply(results, function(r) r$status)
add("## Summary")
add("")
add(sprintf("- **Total datasets**: %d", length(results)))
add(sprintf(
  "- **Changed**: %d", sum(statuses == "CHANGED")
))
add(sprintf(
  "- **Identical**: %d", sum(statuses == "IDENTICAL")
))
add(sprintf(
  "- **New (no baseline)**: %d", sum(statuses == "NEW")
))
add(sprintf(
  "- **Failed**: %d",
  sum(statuses %in% c("PULL_FAILED", "BASELINE_READ_FAILED"))
))
add("")

# Quick overview table
add("## Overview")
add("")
add("| Dataset | Status | Old Rows | New Rows | Type Changes |")
add("|---------|--------|----------|----------|--------------|")
for (ds in names(results)) {
  r <- results[[ds]]
  old_rows <- if (!is.null(r$old_rows)) {
    format(r$old_rows, big.mark = ",")
  } else {
    "-"
  }
  new_rows <- if (!is.null(r$new_rows)) {
    format(r$new_rows, big.mark = ",")
  } else {
    "-"
  }
  tc <- if (!is.null(r$type_change_count)) r$type_change_count else 0
  add(sprintf(
    "| %s | %s | %s | %s | %d |",
    ds, r$status, old_rows, new_rows, tc
  ))
}
add("")

# Detailed sections for changed datasets
changed <- names(results)[statuses == "CHANGED"]
if (length(changed) > 0) {
  add("## Detailed Changes")
  add("")

  for (ds in changed) {
    r <- results[[ds]]
    add(sprintf("### %s", toupper(ds)))
    add("")

    # Row/column summary
    row_mark <- if (r$row_diff == 0) "\u2713" else "\u2717"
    col_mark <- if (length(r$added_cols) == 0 &&
      length(r$removed_cols) == 0) {
      "\u2713"
    } else {
      "\u2717"
    }

    add(sprintf(
      "- Rows: %s \u2192 %s %s",
      format(r$old_rows, big.mark = ","),
      format(r$new_rows, big.mark = ","),
      row_mark
    ))
    add(sprintf(
      "- Columns: %d \u2192 %d %s",
      r$old_col_count, r$new_col_count, col_mark
    ))

    if (length(r$added_cols) > 0) {
      add(sprintf(
        "- Added columns: %s",
        paste(r$added_cols, collapse = ", ")
      ))
    }
    if (length(r$removed_cols) > 0) {
      add(sprintf(
        "- Removed columns: %s",
        paste(r$removed_cols, collapse = ", ")
      ))
    }

    # Type change table
    if (length(r$type_changes) > 0) {
      add(sprintf("- Type changes: %d columns", length(r$type_changes)))
      add("")
      add(
        "| Column | Old Type | New Type |",
        " Old Values (sample) | New Values (sample) |"
      )
      add(
        "|--------|----------|----------|",
        "---------------------|---------------------|"
      )

      for (col in names(r$type_changes)) {
        tc <- r$type_changes[[col]]
        old_vals <- paste(
          head(tc$old_values, 10),
          collapse = ", "
        )
        new_vals <- paste(
          head(tc$new_values, 10),
          collapse = ", "
        )
        # Truncate long value strings
        if (nchar(old_vals) > 60) {
          old_vals <- paste0(substr(old_vals, 1, 57), "...")
        }
        if (nchar(new_vals) > 60) {
          new_vals <- paste0(substr(new_vals, 1, 57), "...")
        }
        add(sprintf(
          "| %s | %s | %s | %s | %s |",
          col, tc$old_type, tc$new_type, old_vals, new_vals
        ))
      }
    }

    add("")
  }
}

# New datasets section
new_ds <- names(results)[statuses == "NEW"]
if (length(new_ds) > 0) {
  add("## New Datasets (no baseline)")
  add("")
  for (ds in new_ds) {
    r <- results[[ds]]
    add(sprintf(
      "- **%s**: %s rows, %d columns",
      toupper(ds),
      format(r$new_rows, big.mark = ","),
      length(r$new_col_names)
    ))
  }
  add("")
}

# Failed datasets section
failed <- names(results)[statuses %in% c(
  "PULL_FAILED", "BASELINE_READ_FAILED"
)]
if (length(failed) > 0) {
  add("## Failed Datasets")
  add("")
  for (ds in failed) {
    r <- results[[ds]]
    add(sprintf("- **%s**: %s", toupper(ds), r$status))
    if (!is.null(r$error)) add(sprintf("  - Error: %s", r$error))
  }
  add("")
}

# Write report
writeLines(lines, report_path)
message(sprintf("\nReport written to: %s", report_path))
