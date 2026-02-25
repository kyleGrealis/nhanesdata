#!/usr/bin/env Rscript

# Workflow Orchestration Script for Automated NHANES Data Updates
# This script is designed to run in GitHub Actions but can also be run locally
#
# Purpose:
#   1. Pull fresh data from CDC servers for all configured datasets
#   2. Detect which datasets have changed using MD5 checksums
#   3. Upload only changed datasets to Cloudflare R2 bucket
#   4. Update checksums file for version tracking
#   5. Generate summary report of updates
#
# Environment Variables Required (for R2 upload):
#   - R2_ACCOUNT_ID
#   - R2_ACCESS_KEY_ID
#   - R2_SECRET_ACCESS_KEY
#
# Usage:
#   Rscript inst/scripts/workflow_update.R [--dry-run] [--datasets demo,bpx,...]
#
# Options:
#   --dry-run     Skip R2 upload (testing mode)
#   --datasets    Comma-separated list of specific datasets (default: all from config)

# Source internal data processing functions
# These are not part of the user-facing package API and live in inst/scripts/
source("inst/scripts/pull_nhanes.R")  # Provides pull_nhanes() and helpers

# Helper function: Create category-based batches
create_category_batches <- function(config, max_batch_size = 50) {
  # Split by category, preserving order: dietary, examination, questionnaire, lab
  category_order <- c("dietary", "examination", "questionnaire", "laboratory")
  batches <- list()
  batch_metadata <- list()

  for (cat in category_order) {
    cat_data <- config[config$category == cat, ]
    if (nrow(cat_data) == 0) next

    # Split category into chunks of max_batch_size
    n_chunks <- ceiling(nrow(cat_data) / max_batch_size)

    for (i in seq_len(n_chunks)) {
      start_idx <- (i - 1) * max_batch_size + 1
      end_idx <- min(i * max_batch_size, nrow(cat_data))
      chunk <- cat_data[start_idx:end_idx, ]

      batches[[length(batches) + 1]] <- chunk

      # Create descriptive metadata
      if (n_chunks == 1) {
        desc <- tools::toTitleCase(cat)
      } else {
        desc <- sprintf(
          "%s %d-%d",
          tools::toTitleCase(cat),
          start_idx,
          end_idx
        )
      }

      batch_metadata[[length(batch_metadata) + 1]] <- list(
        id = length(batches),
        category = cat,
        description = desc,
        count = nrow(chunk)
      )
    }
  }

  list(batches = batches, metadata = batch_metadata)
}

# Helper function: Initialize log file
init_log_file <- function(mode = "PRODUCTION") {
  log_dir <- "inst/logs"
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE)
  }

  log_file <- file.path(
    log_dir,
    sprintf("workflow-update-%s.txt", format(Sys.Date(), "%Y-%m-%d"))
  )

  # Write header
  header <- sprintf(
    "================================================\nNHANES Workflow Update Log\nDate: %s\nMode: %s\n================================================\n\n",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    mode
  )

  writeLines(header, log_file)
  return(log_file)
}

# Helper function: Log dataset processing result
log_dataset <- function(log_file, dataset_name, status, reason = "", uploaded = FALSE) {
  timestamp <- format(Sys.time(), "[%H:%M:%S]")

  action <- if (uploaded) {
    "UPLOADED"
  } else if (status == "failed") {
    "ERROR"
  } else if (status == "incompatible") {
    "SKIPPED (incompatible)"
  } else if (status == "unchanged") {
    "SKIPPED"
  } else if (status == "skipped_cycles") {
    "SKIPPED (incomplete)"
  } else {
    ""
  }

  status_upper <- toupper(status)

  msg <- sprintf(
    "%s %s - %s%s%s\n",
    timestamp,
    dataset_name,
    status_upper,
    if (nzchar(reason)) sprintf(" (%s)", reason) else "",
    if (nzchar(action)) sprintf(" - %s", action) else ""
  )

  cat(msg, file = log_file, append = TRUE)
}

# Helper function: Verify uploaded dataset integrity
verify_r2_upload <- function(dataset_name, original_data, dataset_category = NULL, log_file = NULL) {
  checks <- list()
  all_passed <- TRUE

  # Attempt to download from R2 with retry logic
  downloaded_data <- NULL
  max_attempts <- 3

  for (attempt in seq_len(max_attempts)) {
    downloaded_data <- tryCatch(
      {
        read_nhanes(dataset_name)
      },
      error = function(e) {
        if (attempt < max_attempts) {
          Sys.sleep(10)  # Wait 10 seconds before retry
          NULL
        } else {
          return(list(
            success = FALSE,
            checks_passed = "0/0",
            details = sprintf("Download failed after %d attempts: %s", max_attempts, e$message)
          ))
        }
      }
    )

    if (!is.null(downloaded_data)) break
  }

  # If download failed, return early
  if (is.null(downloaded_data)) {
    return(list(
      success = FALSE,
      checks_passed = "0/5",
      details = sprintf("Download failed after %d attempts", max_attempts)
    ))
  }

  # Check 1: Row count match
  orig_rows <- nrow(original_data)
  down_rows <- nrow(downloaded_data)
  row_match <- orig_rows == down_rows
  checks$row_count <- sprintf("Row count: %d original, %d downloaded", orig_rows, down_rows)
  if (!row_match) all_passed <- FALSE

  # Check 2: Column count match
  orig_cols <- ncol(original_data)
  down_cols <- ncol(downloaded_data)
  col_match <- orig_cols == down_cols
  checks$col_count <- sprintf("Column count: %d original, %d downloaded", orig_cols, down_cols)
  if (!col_match) all_passed <- FALSE

  # Check 3: Column names match
  orig_names <- names(original_data)
  down_names <- names(downloaded_data)
  names_match <- all(orig_names == down_names)
  checks$col_names <- if (names_match) {
    "Column names: match"
  } else {
    sprintf("Column names: mismatch (missing: %s, extra: %s)",
            paste(setdiff(orig_names, down_names), collapse = ", "),
            paste(setdiff(down_names, orig_names), collapse = ", "))
  }
  if (!names_match) all_passed <- FALSE

  # Check 4: Required columns exist
  required_cols <- c("year", "seqn")
  has_required <- all(required_cols %in% down_names)
  checks$required_cols <- if (has_required) {
    "Required columns (year, seqn): present"
  } else {
    sprintf("Required columns: missing %s",
            paste(setdiff(required_cols, down_names), collapse = ", "))
  }
  if (!has_required) all_passed <- FALSE

  # Check 5: Data presence (not empty)
  has_data <- down_rows > 0
  checks$data_presence <- sprintf("Data presence: %d rows", down_rows)
  if (!has_data) all_passed <- FALSE

  # Compile results
  checks_passed <- sum(c(row_match, col_match, names_match, has_required, has_data))
  total_checks <- 5

  return(list(
    success = all_passed,
    checks_passed = sprintf("%d/%d", checks_passed, total_checks),
    details = paste(unlist(checks), collapse = "; ")
  ))
}

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args
sample_mode <- "--sample" %in% args
specific_datasets <- NULL
batch_number <- NULL

# Extract dataset list if provided
dataset_arg_idx <- which(grepl("^--datasets", args))
if (length(dataset_arg_idx) > 0) {
  dataset_arg <- args[dataset_arg_idx]
  if (grepl("=", dataset_arg)) {
    specific_datasets <- strsplit(
      sub("^--datasets=", "", dataset_arg),
      ","
    )[[1]]
  } else if (length(args) > dataset_arg_idx) {
    specific_datasets <- strsplit(args[dataset_arg_idx + 1], ",")[[1]]
  }
}

# Extract batch number if provided (1-6)
batch_arg_idx <- which(grepl("^--batch", args))
if (length(batch_arg_idx) > 0) {
  batch_arg <- args[batch_arg_idx]
  if (grepl("=", batch_arg)) {
    batch_number <- as.integer(sub("^--batch=", "", batch_arg))
  } else if (length(args) > batch_arg_idx) {
    batch_number <- as.integer(args[batch_arg_idx + 1])
  }
  if (!is.na(batch_number) && (batch_number < 1 || batch_number > 9)) {
    stop("Batch number must be between 1 and 9", call. = FALSE)
  }
}

# Load the nhanesdata package
suppressPackageStartupMessages({
  library(nhanesdata)
  library(cli)
})

# Print startup banner
cli_h1("NHANES Data Workflow Update")
cli_alert_info("Mode: {if(dry_run) 'DRY RUN (no R2 upload)' else 'PRODUCTION'}")
cli_alert_info("Date: {Sys.time()}")
cli_rule()

# Initialize summary tracking
summary <- list(
  start_time = Sys.time(),
  datasets_processed = 0,
  datasets_changed = 0,
  datasets_unchanged = 0,
  datasets_failed = 0,
  datasets_incompatible = 0,
  datasets_uploaded = 0,
  datasets_skipped_cycles = 0,
  changed_datasets = character(0),
  failed_datasets = character(0),
  incompatible_datasets = character(0),
  skipped_cycle_details = list()
)

# Initialize log file
log_file <- init_log_file(
  mode = if (dry_run) "DRY RUN (no R2 upload)" else "PRODUCTION"
)
cli_alert_success("Log file created: {log_file}")

# Load dataset configuration
cli_h2("Loading dataset configuration")
tryCatch(
  {
    # Load dataset config from YAML
    if (!requireNamespace("yaml", quietly = TRUE)) {
      stop(
        "Package 'yaml' is required. Install with: install.packages('yaml')",
        call. = FALSE
      )
    }
    config_file <- "inst/extdata/datasets.yml"
    if (!file.exists(config_file)) {
      stop(sprintf("Configuration file not found: %s", config_file))
    }
    config_raw <- yaml::read_yaml(config_file)
    config <- do.call(rbind, lapply(config_raw$datasets, function(x) {
      data.frame(
        name = x$name,
        description = x$description,
        category = x$category,
        notes = ifelse(is.null(x$notes), NA_character_, x$notes),
        stringsAsFactors = FALSE
      )
    }))

    cli_alert_success("Loaded {nrow(config)} datasets from configuration")
  },
  error = function(e) {
    cli_alert_danger("Failed to load dataset configuration: {e$message}")
    quit(status = 1)
  }
)

# Filter to specific datasets if requested
if (!is.null(specific_datasets)) {
  config <- config[config$name %in% specific_datasets, ]
  ds_list <- paste(specific_datasets, collapse = ", ")
  cli_alert_info(
    "Filtered to {nrow(config)} specific datasets: {ds_list}"
  )
}

# Filter to sample datasets if in sample mode
if (sample_mode) {
  sample_file <- "inst/extdata/test_sample.csv"
  if (!file.exists(sample_file)) {
    cli_alert_danger("Sample file not found: {sample_file}")
    cli_alert_info("Generate it with: Rscript inst/scripts/create_random_sample.R")
    quit(status = 1)
  }

  sample_datasets <- read.csv(sample_file)$name
  config <- config[config$name %in% sample_datasets, ]
  cli_alert_warning("SAMPLE MODE: Processing {nrow(config)} test datasets")

  # Show sample breakdown by category
  sample_counts <- table(config$category)
  for (cat in names(sample_counts)) {
    cli_alert_info("  {tools::toTitleCase(cat)}: {sample_counts[cat]} datasets")
  }
}

# Organize datasets into category-based batches (max 20 per batch)
# If --batch parameter provided, process only that batch
# Otherwise, process all batches sequentially with 4-min delays
if (is.null(specific_datasets)) {
  # Create category-based batches dynamically
  batch_result <- create_category_batches(config, max_batch_size = 20)
  all_batches <- batch_result$batches
  batch_info <- batch_result$metadata

  if (!is.null(batch_number) && length(batch_number) > 0) {
    # Process specific batch only
    if (batch_number > length(all_batches)) {
      stop(
        sprintf(
          "Batch %d does not exist. Valid batches: 1-%d",
          batch_number,
          length(all_batches)
        ),
        call. = FALSE
      )
    }
    batches <- list(all_batches[[batch_number]])
    cli_alert_info(
      "Processing batch {batch_number} only: {batch_info[[batch_number]]$description} ({batch_info[[batch_number]]$count} datasets)"
    )
  } else {
    # Process all batches
    batches <- all_batches
    cli_alert_info("Organized into {length(batches)} category-based batches")
    for (i in seq_along(batch_info)) {
      cli_alert_info(
        "  Batch {i}: {batch_info[[i]]$description} ({batch_info[[i]]$count} datasets)"
      )
    }
  }
} else {
  # Specific datasets provided, no batching
  batches <- list(config)
  batch_info <- NULL
}

# Validate R2 credentials (unless dry run)
if (!dry_run) {
  cli_h2("Validating R2 credentials")
  required_vars <- c("R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY")
  missing_vars <- required_vars[!sapply(required_vars, function(x) nzchar(Sys.getenv(x)))]

  if (length(missing_vars) > 0) {
    mv_list <- paste(missing_vars, collapse = ", ")
    cli_alert_danger(
      "Missing required environment variables: {mv_list}"
    )
    cli_alert_info("Set these in GitHub Secrets or your local environment")
    quit(status = 1)
  }
  cli_alert_success("All R2 credentials found")
}

# Process each batch
cli_h2("Processing datasets")
cli_rule()

for (batch_idx in seq_along(batches)) {
  current_batch <- batches[[batch_idx]]

  if (length(batches) > 1) {
    if (!is.null(batch_info)) {
      cli_h2("Batch {batch_idx}/{length(batches)}: {batch_info[[batch_idx]]$description}")
      cli_alert_info("{batch_info[[batch_idx]]$count} datasets in this batch")
      # Log batch start
      cat(
        sprintf(
          "\n[%s] Batch %d/%d: %s (%d datasets)\n",
          format(Sys.time(), "%H:%M:%S"),
          batch_idx,
          length(batches),
          batch_info[[batch_idx]]$description,
          batch_info[[batch_idx]]$count
        ),
        file = log_file,
        append = TRUE
      )
    } else {
      cli_h2("Batch {batch_idx}/{length(batches)}")
      cli_alert_info("{nrow(current_batch)} datasets in this batch")
      # Log batch start
      cat(
        sprintf(
          "\n[%s] Batch %d/%d: (%d datasets)\n",
          format(Sys.time(), "%H:%M:%S"),
          batch_idx,
          length(batches),
          nrow(current_batch)
        ),
        file = log_file,
        append = TRUE
      )
    }
    cli_rule()
  }

  for (i in seq_len(nrow(current_batch))) {
    dataset_name <- current_batch$name[i]
    dataset_desc <- current_batch$description[i]
    dataset_category <- current_batch$category[i]

  cli_h3("{i}/{nrow(config)}: {toupper(dataset_name)}")
  cli_alert_info("Description: {dataset_desc}")

  summary$datasets_processed <- summary$datasets_processed + 1

  # Step 1: Pull data from CDC
  cli_alert("Pulling data from CDC servers...")

  dataset_obj <- tryCatch(
    {
      pull_nhanes(dataset_name, save = TRUE)
    },
    error = function(e) {
      err_msg <- conditionMessage(e)

      # Categorize error types
      is_incompatible <- grepl("seqn.*not found|year.*not found", err_msg, ignore.case = TRUE)

      if (is_incompatible) {
        error_type <- "incompatible structure (reference table, not participant data)"
        cli_alert_warning("Skipping {dataset_name}: {error_type}")
        summary$datasets_incompatible <<- summary$datasets_incompatible + 1
        summary$incompatible_datasets <<- c(summary$incompatible_datasets, dataset_name)
      } else {
        error_type <- if (grepl("timeout|timed out", err_msg, ignore.case = TRUE)) {
          "network timeout"
        } else if (grepl("connection|socket", err_msg, ignore.case = TRUE)) {
          "connection error"
        } else {
          "pull error"
        }
        cli_alert_danger("Failed to pull {dataset_name}: {error_type}")
        cli_alert_info("Error details: {err_msg}")
        summary$datasets_failed <<- summary$datasets_failed + 1
        summary$failed_datasets <<- c(summary$failed_datasets, dataset_name)
      }

      # Return list with error info for logging
      list(error = TRUE, type = error_type, message = err_msg, incompatible = is_incompatible)
    }
  )

  if (is.list(dataset_obj) && isTRUE(dataset_obj$error)) {
    log_dataset(
      log_file,
      dataset_name,
      if (isTRUE(dataset_obj$incompatible)) "incompatible" else "failed",
      dataset_obj$type,
      uploaded = FALSE
    )
    cli_rule()
    closeAllConnections()
    next
  }

  if (is.null(dataset_obj)) {
    log_dataset(log_file, dataset_name, "failed", "unknown error", uploaded = FALSE)
    cli_rule()
    closeAllConnections()
    next
  }

  # Check for empty dataset (no data available in any cycle)
  if (nrow(dataset_obj) == 0) {
    cli_alert_warning("No data available for {dataset_name} in any cycle - skipping")
    log_dataset(log_file, dataset_name, "skipped", "no data available", uploaded = FALSE)
    cli_rule()
    closeAllConnections()
    next
  }

  cli_alert_success("Downloaded {scales::comma(nrow(dataset_obj))} rows")

  # Check for skipped cycles (transient CDC API failures)
  skipped <- attr(dataset_obj, "skipped_cycles")
  if (!is.null(skipped) && length(skipped) > 0) {
    summary$datasets_skipped_cycles <- summary$datasets_skipped_cycles + 1
    summary$skipped_cycle_details[[dataset_name]] <- skipped
    cli_alert_danger(paste0(
      "SKIPPING upload for {dataset_name}: ",
      "{length(skipped)} cycle(s) failed after retries: ",
      "{paste(skipped, collapse = ', ')}"
    ))
    cli_alert_warning(paste0(
      "Data may be incomplete. Will not overwrite R2 ",
      "with potentially missing cycles."
    ))
    log_dataset(
      log_file,
      dataset_name,
      "skipped_cycles",
      sprintf("missing cycles: %s", paste(skipped, collapse = ", ")),
      uploaded = FALSE
    )
    cli_rule()
    closeAllConnections()
    next
  }

  # Step 2: Check if data has changed (hash data, not file)
  checksums_file <- ".checksums.json"

  cli_alert("Checking for changes...")
  # Detect data changes via data hashing (pre-Parquet)
  json_ok <- requireNamespace("jsonlite", quietly = TRUE)
  digest_ok <- requireNamespace("digest", quietly = TRUE)
  if (!json_ok || !digest_ok) {
    stop(
      "Packages 'jsonlite' and 'digest' are required. ",
      "Install with: install.packages(c('jsonlite', 'digest'))",
      call. = FALSE
    )
  }

  # Sort data for deterministic hashing
  dataset_sorted <- dataset_obj |>
    dplyr::arrange(year, seqn)

  # Hash the sorted tibble (pre-Parquet)
  new_hash <- digest::digest(dataset_sorted, algo = "md5")

  # Load stored hashes
  checksums <- if (file.exists(checksums_file)) {
    jsonlite::read_json(checksums_file, simplifyVector = TRUE)
  } else {
    list()
  }

  stored_hash <- checksums[[dataset_name]]

  has_changed <- if (is.null(stored_hash)) {
    message(sprintf("%s: NEW dataset (no previous hash)", dataset_name))
    TRUE
  } else if (new_hash != stored_hash) {
    message(sprintf("%s: CHANGED (data hash mismatch)", dataset_name))
    TRUE
  } else {
    message(sprintf("%s: UNCHANGED (data hash match)", dataset_name))
    FALSE
  }

  if (has_changed) {
    summary$datasets_changed <- summary$datasets_changed + 1
    summary$changed_datasets <- c(summary$changed_datasets, dataset_name)

    # Step 3: Upload to R2 (if not dry run)
    if (!dry_run) {
      cli_alert("Uploading to R2 bucket...")

      upload_success <- tryCatch(
        {
          nhanesdata:::nhanes_r2_upload(
            x = dataset_obj,
            name = dataset_name,
            bucket = "nhanes-data"
          )
          TRUE
        },
        error = function(e) {
          cli_alert_danger("R2 upload failed: {conditionMessage(e)}")
          summary$datasets_failed <- summary$datasets_failed + 1
          summary$failed_datasets <- c(summary$failed_datasets, dataset_name)
          FALSE
        }
      )

      if (upload_success) {
        summary$datasets_uploaded <- summary$datasets_uploaded + 1
        cli_alert_success("Uploaded to R2")

        # Verify upload integrity (only during live uploads)
        if (!dry_run) {
          cli_alert_info("Verifying upload integrity...")
          verify_result <- verify_r2_upload(
            dataset_name = dataset_name,
            original_data = dataset_obj,
            dataset_category = dataset_category,
            log_file = log_file
          )

          if (!verify_result$success) {
            cli_alert_danger("Verification FAILED: {verify_result$details}")
            log_dataset(
              log_file,
              dataset_name,
              "verification_failed",
              verify_result$details,
              uploaded = FALSE
            )
            stop(sprintf("Upload verification failed for %s. Halting workflow.", dataset_name),
                 call. = FALSE)
          }

          cli_alert_success("Verification passed: {verify_result$checks_passed}")
          log_dataset(
            log_file,
            dataset_name,
            "verified",
            verify_result$checks_passed,
            uploaded = TRUE
          )
        }

        # Step 4: Update data hash for this dataset
        checksums <- if (file.exists(checksums_file)) {
          jsonlite::read_json(checksums_file, simplifyVector = TRUE)
        } else {
          list()
        }

        checksums[[dataset_name]] <- new_hash
        checksums <- checksums[sort(names(checksums))]

        jsonlite::write_json(
          checksums,
          checksums_file,
          pretty = TRUE,
          auto_unbox = TRUE
        )

        message(sprintf("Updated data hash for %s", dataset_name))
        log_dataset(
          log_file,
          dataset_name,
          "changed",
          if (is.null(stored_hash)) "new dataset" else "data hash mismatch",
          uploaded = TRUE
        )
      } else {
        log_dataset(
          log_file,
          dataset_name,
          "failed",
          "R2 upload failed",
          uploaded = FALSE
        )
      }
    } else {
      cli_alert_warning("SKIPPED upload (dry run mode)")
      log_dataset(
        log_file,
        dataset_name,
        "changed",
        if (is.null(stored_hash)) "new dataset" else "data hash mismatch",
        uploaded = FALSE
      )
    }
  } else {
    summary$datasets_unchanged <- summary$datasets_unchanged + 1
    cli_alert_info("No changes detected - skipping upload")
    log_dataset(
      log_file,
      dataset_name,
      "unchanged",
      "data hash match",
      uploaded = FALSE
    )
  }

  cli_rule()

  # Aggressive memory cleanup after each dataset
  # Close any lingering connections to avoid R's 128 connection limit
  closeAllConnections()
  # Force garbage collection to free memory
  gc(verbose = FALSE, full = TRUE)
  # Remove large objects from workspace
  if (exists("dataset_obj")) rm(dataset_obj)
  if (exists("dataset_sorted")) rm(dataset_sorted)
  if (exists("parquet_temp")) rm(parquet_temp)
  }

  # Add delay between batches to avoid CDC rate limiting
  if (batch_idx < length(batches)) {
    cli_h3("Batch {batch_idx} complete")
    cli_alert_warning(
      "Waiting 4 minutes before next batch to avoid CDC rate limiting..."
    )
    cli_alert_info("Next batch: {batch_idx + 1}/{length(batches)}")

    # Sleep for 4 minutes (240 seconds)
    Sys.sleep(240)

    cli_alert_success("Resuming processing")
    cli_rule()
  }
}

# Generate summary report
end_time <- Sys.time()
duration_mins <- difftime(end_time, summary$start_time, units = "mins")

# Convert to JSON-serializable types
summary$start_time <- format(summary$start_time, "%Y-%m-%d %H:%M:%S")
summary$end_time <- format(end_time, "%Y-%m-%d %H:%M:%S")
# Explicitly strip difftime class by unlassing first, then converting to numeric
# This ensures all S3 class attributes are removed before JSON serialization
summary$duration_minutes <- as.numeric(unclass(duration_mins))

cli_h1("Workflow Summary")
cli_alert_info("Duration: {round(duration_mins, 2)} minutes")
cli_alert_info("Total datasets processed: {summary$datasets_processed}")
cli_alert_success("Changed datasets: {summary$datasets_changed}")
cli_alert_info("Unchanged datasets: {summary$datasets_unchanged}")

if (!dry_run) {
  cli_alert_success("Uploaded to R2: {summary$datasets_uploaded}")
}

if (summary$datasets_skipped_cycles > 0) {
  cli_alert_warning(
    "Skipped upload (missing cycles): {summary$datasets_skipped_cycles}"
  )
  for (ds in names(summary$skipped_cycle_details)) {
    cycles <- summary$skipped_cycle_details[[ds]]
    cli_alert_warning(
      "  {ds}: missing {paste(cycles, collapse = ', ')}"
    )
  }
}

if (summary$datasets_incompatible > 0) {
  cli_alert_info("Incompatible datasets: {summary$datasets_incompatible}")
  cli_alert_info(
    "Incompatible: {paste(summary$incompatible_datasets, collapse = ', ')}"
  )
}

if (summary$datasets_failed > 0) {
  cli_alert_danger("Failed datasets: {summary$datasets_failed}")
  cli_alert_warning(
    "Failed: {paste(summary$failed_datasets, collapse = ', ')}"
  )
}

# Print changed datasets
if (length(summary$changed_datasets) > 0) {
  cli_h2("Changed Datasets")
  for (ds in summary$changed_datasets) {
    cli_li(ds)
  }
}

# Write summary to log file
cat(
  sprintf(
    "\n================================================\nSUMMARY\nDuration: %.1f minutes\nProcessed: %d datasets\nChanged: %d datasets\nUnchanged: %d datasets\nIncompatible: %d datasets\nFailed: %d datasets\nUploaded: %d datasets\n================================================\n",
    as.numeric(unclass(duration_mins)),
    summary$datasets_processed,
    summary$datasets_changed,
    summary$datasets_unchanged,
    summary$datasets_incompatible,
    summary$datasets_failed,
    summary$datasets_uploaded
  ),
  file = log_file,
  append = TRUE
)

if (length(summary$changed_datasets) > 0) {
  cat("\nChanged datasets:\n", file = log_file, append = TRUE)
  for (ds in summary$changed_datasets) {
    cat(sprintf("- %s\n", ds), file = log_file, append = TRUE)
  }
}

if (length(summary$incompatible_datasets) > 0) {
  cat("\nIncompatible datasets (reference tables, not participant data):\n", file = log_file, append = TRUE)
  for (ds in summary$incompatible_datasets) {
    cat(sprintf("- %s\n", ds), file = log_file, append = TRUE)
  }
}

if (length(summary$failed_datasets) > 0) {
  cat("\nFailed datasets:\n", file = log_file, append = TRUE)
  for (ds in summary$failed_datasets) {
    cat(sprintf("- %s\n", ds), file = log_file, append = TRUE)
  }
}

if (length(summary$skipped_cycle_details) > 0) {
  cat("\nSkipped (incomplete cycles):\n", file = log_file, append = TRUE)
  for (ds in names(summary$skipped_cycle_details)) {
    cycles <- summary$skipped_cycle_details[[ds]]
    cat(
      sprintf("- %s: %s\n", ds, paste(cycles, collapse = ", ")),
      file = log_file,
      append = TRUE
    )
  }
}

cat("\n", file = log_file, append = TRUE)
cli_alert_success("Log file updated: {log_file}")

# Save summary as JSON for GitHub Actions artifact
summary_json <- jsonlite::toJSON(summary, pretty = TRUE, auto_unbox = FALSE)
summary_file <- "inst/logs/workflow_summary.json"
writeLines(summary_json, summary_file)
cli_alert_success("Summary saved to {summary_file}")

# Exit with appropriate status
if (summary$datasets_failed > 0) {
  cli_alert_warning("Workflow completed with failures")
  quit(status = 1)
} else if (summary$datasets_skipped_cycles > 0) {
  cli_alert_warning(paste0(
    "Workflow completed but {summary$datasets_skipped_cycles} ",
    "dataset(s) skipped due to missing CDC cycles"
  ))
  quit(status = 1)
} else {
  cli_alert_success("Workflow completed successfully")
  quit(status = 0)
}
