# seed_coverage_baselines.R
#
# One-off: seed per-dataset coverage into .checksums.json from the
# parquets currently published on R2.
#
# The regression gate added to workflow_update.R compares each new build
# against the previous build's coverage. Every existing entry is a bare
# hash string with no coverage, so without seeding the gate stays inert
# until a dataset has been rebuilt twice. This reads the live parquets
# and backfills rows, years, and cols.
#
# Deliberately does NOT touch the stored hash. Hashes are computed on the
# pulled tibble before parquet conversion, so a hash derived from a
# parquet read-back would not match a fresh pull and would mark every
# dataset as CHANGED on the next run.
#
# Seeding from current state treats whatever is published today as the
# baseline. It prevents future regressions; it does not detect past ones.
# Datasets already short a cycle stay short until the CDC cross-check
# identifies them.
#
# Usage:
#   Rscript inst/scripts/seed_coverage_baselines.R [--dry-run]

suppressPackageStartupMessages({
  library(dplyr)
})

args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args

base_url <- "https://nhanes.kylegrealis.com"
checksums_file <- ".checksums.json"

stopifnot(file.exists(checksums_file))

# Known-huge accelerometry files: skipped, they keep their bare hash and
# simply gain coverage on their next rebuild.
skip_datasets <- c("paxday", "paxhd", "paxhr", "paxmin", "paxraw")

checksums <- jsonlite::read_json(checksums_file, simplifyVector = TRUE)

# "_comment" and any other non-dataset metadata key must pass through
# untouched.
is_meta <- function(nm) startsWith(nm, "_")

targets <- names(checksums)[!is_meta(names(checksums))]
targets <- setdiff(targets, skip_datasets)

message(sprintf(
  "Seeding coverage for %d datasets (%d skipped, %d metadata keys)",
  length(targets), length(skip_datasets),
  sum(is_meta(names(checksums)))
))

seeded <- 0L
failed <- character(0)
already <- 0L

for (ds in targets) {
  entry <- checksums[[ds]]

  # Already has coverage from a post-gate build: leave it alone.
  if (is.list(entry) && !is.null(entry$rows)) {
    already <- already + 1L
    next
  }

  url <- sprintf("%s/%s.parquet", base_url, ds)
  dat <- tryCatch(arrow::read_parquet(url), error = function(e) e)

  if (inherits(dat, "error")) {
    message(sprintf("  %-14s FAILED: %s", ds, conditionMessage(dat)))
    failed <- c(failed, ds)
    next
  }

  yrs <- sort(unique(dat$year))
  checksums[[ds]] <- list(
    hash = if (is.list(entry)) entry$hash else entry,
    rows = nrow(dat),
    years = yrs,
    cols = sort(names(dat))
  )
  seeded <- seeded + 1L

  message(sprintf(
    "  %-14s rows=%-9s cycles=%s",
    ds, format(nrow(dat), big.mark = ","), paste(yrs, collapse = ",")
  ))

  rm(dat)
  invisible(gc(verbose = FALSE))
}

cat("\n================ SEED SUMMARY ================\n")
cat(sprintf("seeded          : %d\n", seeded))
cat(sprintf("already had cov : %d\n", already))
cat(sprintf("skipped (large) : %d\n", length(skip_datasets)))
cat(sprintf("failed          : %d\n", length(failed)))
if (length(failed) > 0) {
  cat(sprintf("  %s\n", paste(failed, collapse = ", ")))
}

if (dry_run) {
  cat("\nDRY RUN - .checksums.json not written\n")
} else {
  checksums <- checksums[order(names(checksums))]
  jsonlite::write_json(
    checksums, checksums_file,
    pretty = TRUE, auto_unbox = TRUE
  )
  cat(sprintf("\nwrote %s\n", checksums_file))
}
cat("=============================================\n")
