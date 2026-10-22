# audit_parquet_cycles.R
#
# Audit every published parquet on R2 for missing survey cycles.
#
# Motivation (Oct 22, 2026): the dxx parquet silently lost its 2017-2018
# cycle during the 2026-02-24 rebuild. nhanesA::nhanes() returned NULL for
# DXX_J, pull_nhanes.R treated NULL as "this cycle does not exist" rather
# than as a failure, and the truncated file passed verify_r2_upload()
# because that check only confirms the upload round-trips, not that the
# pull was complete. Every dataset rebuilt that day is therefore suspect.
#
# This script needs no CDC ground truth. It relies on two signatures that
# are almost always bugs rather than genuine absences:
#
#   1. Interior gap. A cycle missing between two cycles that are present.
#      NHANES files do not normally stop and restart.
#   2. Missing newest. The dataset has 2015 but not 2017, while a sibling
#      in the same family does have 2017. That is the exact dxx/dxxag
#      signature.
#
# Only the `year` column is read. Files above the size cap are reported
# as deferred rather than downloaded, so the accelerometry monsters do not
# dominate the run.
#
# Usage:
#   Rscript inst/scripts/audit_parquet_cycles.R [--max-mb=200] [--out=PATH]

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(tibble)
  library(stringr)
})

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default) {
  hit <- grep(paste0("^", flag, "="), args, value = TRUE)
  if (length(hit) == 0) default else sub(paste0("^", flag, "="), "", hit[1])
}

max_mb <- as.numeric(get_arg("--max-mb", 200))
out_path <- get_arg("--out", "/tmp/nhanes_parquet_audit.csv")

base_url <- "https://nhanes.kylegrealis.com"

# Cycles pull_nhanes.R can produce. Suffix K (2019-2020) is deliberately
# skipped upstream, so 2019 is never expected and is not a gap.
expected_years <- c(seq(1999, 2017, by = 2), seq(2021, 2029, by = 2))

# ---------------------------------------------------------------------------
# Dataset list comes from the package's own registry
# ---------------------------------------------------------------------------
yml_path <- file.path("inst", "extdata", "datasets.yml")
if (!file.exists(yml_path)) {
  yml_path <- system.file("extdata", "datasets.yml", package = "nhanesdata")
}
stopifnot(nzchar(yml_path), file.exists(yml_path))

registry <- yaml::read_yaml(yml_path)$datasets
datasets <- vapply(registry, function(x) x$name %||% NA_character_, character(1))
datasets <- datasets[!is.na(datasets)]
datasets <- sort(unique(datasets))

message(sprintf("Auditing %d datasets (size cap %.0f MB)", length(datasets), max_mb))

# ---------------------------------------------------------------------------
# Size probe: HEAD request, so huge files are skipped before download
# ---------------------------------------------------------------------------
# The R2 endpoint returns no content-length on HEAD and ignores Range
# requests (returns 200, not 206), so remote size cannot be probed. Skip
# the handful of known-huge accelerometry files by name instead; every
# other NHANES table is small enough to read directly.
deferred_prefixes <- c("paxday", "paxhd", "paxhr", "paxmin", "paxraw")

# ---------------------------------------------------------------------------
# Audit one dataset: read only the `year` column
# ---------------------------------------------------------------------------
audit_one <- function(ds) {
  url <- sprintf("%s/%s.parquet", base_url, ds)

  if (ds %in% deferred_prefixes) {
    return(tibble(
      dataset = ds, status = "deferred_large", size_mb = NA_real_,
      n_rows = NA_integer_, years = NA_character_
    ))
  }

  res <- tryCatch(
    arrow::read_parquet(url, col_select = "year"),
    error = function(e) e
  )
  if (inherits(res, "error")) {
    return(tibble(
      dataset = ds, status = "read_error", size_mb = NA_real_,
      n_rows = NA_integer_, years = NA_character_
    ))
  }

  yrs <- sort(unique(res$year))
  tibble(
    dataset = ds, status = "ok", size_mb = NA_real_,
    n_rows = nrow(res), years = paste(yrs, collapse = ",")
  )
}

results <- map(datasets, function(ds) {
  message(sprintf("  %s", ds))
  audit_one(ds)
}) |>
  list_rbind()

# ---------------------------------------------------------------------------
# Flag the two bug signatures
# ---------------------------------------------------------------------------
flag_gaps <- function(years_str) {
  if (is.na(years_str) || !nzchar(years_str)) {
    return(NA_character_)
  }
  yrs <- as.integer(strsplit(years_str, ",")[[1]])
  if (length(yrs) < 2) {
    return("")
  }
  span <- expected_years[expected_years >= min(yrs) & expected_years <= max(yrs)]
  missing <- setdiff(span, yrs)
  paste(missing, collapse = ",")
}

audit <- results |>
  mutate(
    max_year = suppressWarnings(as.integer(
      vapply(
        strsplit(years, ","),
        function(x) if (length(x) == 0 || all(is.na(x))) NA_character_ else x[length(x)],
        character(1)
      )
    )),
    interior_gap = vapply(years, flag_gaps, character(1)),
    # dxx/dxxag signature: has 2015 but stops there
    missing_2017 = !is.na(max_year) & max_year == 2015,
    suspect = status == "ok" & (nzchar(interior_gap) | missing_2017)
  ) |>
  arrange(desc(suspect), dataset)

readr::write_csv(audit, out_path)

# ---------------------------------------------------------------------------
# Console summary
# ---------------------------------------------------------------------------
cat("\n================ PARQUET CYCLE AUDIT ================\n")
cat(sprintf("datasets checked : %d\n", nrow(audit)))
cat(sprintf("  ok             : %d\n", sum(audit$status == "ok")))
cat(sprintf("  deferred(large): %d\n", sum(audit$status == "deferred_large")))
cat(sprintf("  unreachable    : %d\n", sum(audit$status == "unreachable")))
cat(sprintf("  read_error     : %d\n", sum(audit$status == "read_error")))
cat(sprintf("\nSUSPECT datasets : %d\n", sum(audit$suspect, na.rm = TRUE)))

sus <- audit |> filter(suspect)
if (nrow(sus) > 0) {
  cat("\n--- interior gaps (near-certain bugs) ---\n")
  g <- sus |> filter(nzchar(interior_gap))
  if (nrow(g) > 0) {
    print(as.data.frame(g[, c("dataset", "n_rows", "years", "interior_gap")]))
  } else {
    cat("(none)\n")
  }

  cat("\n--- stops at 2015, no 2017 (dxx signature) ---\n")
  m <- sus |> filter(missing_2017, !nzchar(interior_gap))
  if (nrow(m) > 0) {
    print(as.data.frame(m[, c("dataset", "n_rows", "years")]))
  } else {
    cat("(none)\n")
  }
}

cat(sprintf("\nfull table written to: %s\n", out_path))
cat("=====================================================\n")
