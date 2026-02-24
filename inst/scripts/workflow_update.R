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

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args
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
  if (!batch_number %in% 1:6) {
    stop("Batch number must be between 1 and 6", call. = FALSE)
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
  datasets_uploaded = 0,
  datasets_skipped_cycles = 0,
  changed_datasets = character(0),
  failed_datasets = character(0),
  skipped_cycle_details = list()
)

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

# Organize datasets into batches (60 per batch, grouped by category)
# If --batch parameter provided, process only that batch
# Otherwise, process all batches sequentially with 10-min delays
if (is.null(specific_datasets) && (is.null(batch_number) || length(batch_number) == 0)) {
  # Split config by category for organized batching
  dietary <- config[config$category == "dietary", ]
  examination <- config[config$category == "examination", ]
  questionnaire <- config[config$category == "questionnaire", ]
  laboratory <- config[config$category == "laboratory", ]

  # Create 6 batches of ~60 datasets each
  batches <- list(
    rbind(dietary, examination[1:min(40, nrow(examination)), ]),
    rbind(
      examination[41:min(nrow(examination), 63), ],
      questionnaire[1:min(37, nrow(questionnaire)), ]
    ),
    rbind(
      questionnaire[38:min(nrow(questionnaire), nrow(questionnaire)), ],
      laboratory[1:min(26, nrow(laboratory)), ]
    ),
    laboratory[27:min(86, nrow(laboratory)), ],
    laboratory[87:min(146, nrow(laboratory)), ],
    laboratory[147:nrow(laboratory), ]
  )

  # Remove empty batches
  batches <- batches[sapply(batches, function(b) !is.null(b) && nrow(b) > 0)]

  cli_alert_info("Organized into {length(batches)} batches")
  for (i in seq_along(batches)) {
    cli_alert_info(
      "  Batch {i}: {nrow(batches[[i]])} datasets"
    )
  }
} else if (!is.null(batch_number)) {
  # Process specific batch only
  dietary <- config[config$category == "dietary", ]
  examination <- config[config$category == "examination", ]
  questionnaire <- config[config$category == "questionnaire", ]
  laboratory <- config[config$category == "laboratory", ]

  batches <- list(
    rbind(dietary, examination[1:min(40, nrow(examination)), ]),
    rbind(
      examination[41:min(nrow(examination), 63), ],
      questionnaire[1:min(37, nrow(questionnaire)), ]
    ),
    rbind(
      questionnaire[38:min(nrow(questionnaire), nrow(questionnaire)), ],
      laboratory[1:min(26, nrow(laboratory)), ]
    ),
    laboratory[27:min(86, nrow(laboratory)), ],
    laboratory[87:min(146, nrow(laboratory)), ],
    laboratory[147:nrow(laboratory), ]
  )

  batches <- list(batches[[batch_number]])
  cli_alert_info("Processing batch {batch_number} only ({nrow(batches[[1]])} datasets)")
} else {
  # Specific datasets provided, no batching
  batches <- list(config)
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
    cli_h2("Batch {batch_idx}/{length(batches)}")
    cli_alert_info("{nrow(current_batch)} datasets in this batch")
    cli_rule()
  }

  for (i in seq_len(nrow(current_batch))) {
    dataset_name <- current_batch$name[i]
    dataset_desc <- current_batch$description[i]

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
      cli_alert_danger("Failed to pull {dataset_name}: {e$message}")
      summary$datasets_failed <- summary$datasets_failed + 1
      summary$failed_datasets <- c(summary$failed_datasets, dataset_name)
      NULL
    }
  )

  if (is.null(dataset_obj)) {
    cli_rule()
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
    cli_rule()
    next
  }

  # Step 2: Check if data has changed
  parquet_path <- sprintf("data/raw/parquet/%s.parquet", dataset_name)
  checksums_file <- ".checksums.json"

  cli_alert("Checking for changes...")
  # Detect data changes via checksum comparison
  tools_ok <- requireNamespace("tools", quietly = TRUE)
  json_ok <- requireNamespace("jsonlite", quietly = TRUE)
  if (!tools_ok || !json_ok) {
    stop(
      "Packages 'tools' and 'jsonlite' are required. ",
      "Install with: install.packages(c('tools', 'jsonlite'))",
      call. = FALSE
    )
  }

  has_changed <- if (!file.exists(parquet_path)) {
    warning(sprintf("File not found: %s", parquet_path))
    FALSE
  } else {
    new_hash <- tools::md5sum(parquet_path)
    names(new_hash) <- NULL

    checksums <- if (file.exists(checksums_file)) {
      jsonlite::read_json(checksums_file, simplifyVector = TRUE)
    } else {
      list()
    }

    stored_hash <- checksums[[dataset_name]]

    if (is.null(stored_hash)) {
      message(sprintf("%s: NEW dataset (no previous checksum)", dataset_name))
      TRUE
    } else if (new_hash != stored_hash) {
      message(sprintf("%s: CHANGED (hash mismatch)", dataset_name))
      TRUE
    } else {
      message(sprintf("%s: UNCHANGED (hash match)", dataset_name))
      FALSE
    }
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

        # Step 4: Update checksum for this dataset
        if (!file.exists(parquet_path)) {
          stop(sprintf("File not found: %s", parquet_path))
        }

        new_hash <- tools::md5sum(parquet_path)
        names(new_hash) <- NULL

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

        message(sprintf("Updated checksum for %s", dataset_name))
      }
    } else {
      cli_alert_warning("SKIPPED upload (dry run mode)")
    }
  } else {
    summary$datasets_unchanged <- summary$datasets_unchanged + 1
    cli_alert_info("No changes detected - skipping upload")
  }

  cli_rule()
  }

  # Add delay between batches to avoid CDC rate limiting
  if (batch_idx < length(batches)) {
    cli_h3("Batch {batch_idx} complete")
    cli_alert_warning(
      "Waiting 10 minutes before next batch to avoid CDC rate limiting..."
    )
    cli_alert_info("Next batch: {batch_idx + 1}/{length(batches)}")

    # Sleep for 10 minutes (600 seconds)
    Sys.sleep(600)

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

# Save summary as JSON for GitHub Actions artifact
summary_json <- jsonlite::toJSON(summary, pretty = TRUE, auto_unbox = FALSE)
writeLines(summary_json, "workflow_summary.json")
cli_alert_success("Summary saved to workflow_summary.json")

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
