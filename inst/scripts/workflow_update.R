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

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args
specific_datasets <- NULL

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
  changed_datasets = character(0),
  failed_datasets = character(0)
)

# Load dataset configuration
cli_h2("Loading dataset configuration")
tryCatch({
  config <- load_dataset_config('inst/extdata/datasets.yml')
  cli_alert_success("Loaded {nrow(config)} datasets from configuration")
}, error = function(e) {
  cli_alert_danger("Failed to load dataset configuration: {e$message}")
  quit(status = 1)
})

# Filter to specific datasets if requested
if (!is.null(specific_datasets)) {
  config <- config[config$name %in% specific_datasets, ]
  cli_alert_info("Filtered to {nrow(config)} specific datasets: {paste(specific_datasets, collapse=', ')}")
}

# Validate R2 credentials (unless dry run)
if (!dry_run) {
  cli_h2("Validating R2 credentials")
  required_vars <- c("R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY")
  missing_vars <- required_vars[!sapply(required_vars, function(x) nzchar(Sys.getenv(x)))]

  if (length(missing_vars) > 0) {
    cli_alert_danger("Missing required environment variables: {paste(missing_vars, collapse=', ')}")
    cli_alert_info("Set these in GitHub Secrets or your local environment")
    quit(status = 1)
  }
  cli_alert_success("All R2 credentials found")
}

# Process each dataset
cli_h2("Processing datasets")
cli_rule()

for (i in seq_len(nrow(config))) {
  dataset_name <- config$name[i]
  dataset_desc <- config$description[i]

  cli_h3("{i}/{nrow(config)}: {toupper(dataset_name)}")
  cli_alert_info("Description: {dataset_desc}")

  summary$datasets_processed <- summary$datasets_processed + 1

  # Step 1: Pull data from CDC
  cli_alert("Pulling data from CDC servers...")

  dataset_obj <- tryCatch({
    pull_nhanes(dataset_name, save = TRUE)
  }, error = function(e) {
    cli_alert_danger("Failed to pull {dataset_name}: {e$message}")
    summary$datasets_failed <- summary$datasets_failed + 1
    summary$failed_datasets <- c(summary$failed_datasets, dataset_name)
    return(NULL)
  })

  if (is.null(dataset_obj)) {
    cli_rule()
    next
  }

  cli_alert_success("Downloaded {scales::comma(nrow(dataset_obj))} rows")

  # Step 2: Check if data has changed
  parquet_path <- sprintf('data/raw/parquet/%s.parquet', dataset_name)

  cli_alert("Checking for changes...")
  has_changed <- detect_data_changes(
    file_path = parquet_path,
    dataset_name = dataset_name,
    checksums_file = '.checksums.json'
  )

  if (has_changed) {
    summary$datasets_changed <- summary$datasets_changed + 1
    summary$changed_datasets <- c(summary$changed_datasets, dataset_name)

    # Step 3: Upload to R2 (if not dry run)
    if (!dry_run) {
      cli_alert("Uploading to R2 bucket...")

      upload_success <- tryCatch({
        nhanes_pin_write(
          x = dataset_obj,
          name = dataset_name,
          bucket = 'nhanes-data'
        )
        TRUE
      }, error = function(e) {
        cli_alert_danger("R2 upload failed: {e$message}")
        summary$datasets_failed <- summary$datasets_failed + 1
        summary$failed_datasets <- c(summary$failed_datasets, dataset_name)
        FALSE
      })

      if (upload_success) {
        summary$datasets_uploaded <- summary$datasets_uploaded + 1
        cli_alert_success("Uploaded to R2")

        # Step 4: Update checksum
        update_checksum(
          dataset_name = dataset_name,
          file_path = parquet_path,
          checksums_file = '.checksums.json'
        )
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

# Generate summary report
end_time <- Sys.time()
duration_mins <- difftime(end_time, summary$start_time, units = "mins")

# Convert to JSON-serializable types
summary$start_time <- format(summary$start_time, "%Y-%m-%d %H:%M:%S")
summary$end_time <- format(end_time, "%Y-%m-%d %H:%M:%S")
summary$duration_minutes <- as.numeric(duration_mins)

cli_h1("Workflow Summary")
cli_alert_info("Duration: {round(duration_mins, 2)} minutes")
cli_alert_info("Total datasets processed: {summary$datasets_processed}")
cli_alert_success("Changed datasets: {summary$datasets_changed}")
cli_alert_info("Unchanged datasets: {summary$datasets_unchanged}")

if (!dry_run) {
  cli_alert_success("Uploaded to R2: {summary$datasets_uploaded}")
}

if (summary$datasets_failed > 0) {
  cli_alert_danger("Failed datasets: {summary$datasets_failed}")
  cli_alert_warning("Failed: {paste(summary$failed_datasets, collapse=', ')}")
}

# Print changed datasets
if (length(summary$changed_datasets) > 0) {
  cli_h2("Changed Datasets")
  for (ds in summary$changed_datasets) {
    cli_li(ds)
  }
}

# Save summary as JSON for GitHub Actions artifact
summary_json <- jsonlite::toJSON(summary, pretty = TRUE, auto_unbox = TRUE)
writeLines(summary_json, 'workflow_summary.json')
cli_alert_success("Summary saved to workflow_summary.json")

# Exit with appropriate status
if (summary$datasets_failed > 0) {
  cli_alert_warning("Workflow completed with failures")
  quit(status = 1)
} else {
  cli_alert_success("Workflow completed successfully")
  quit(status = 0)
}
