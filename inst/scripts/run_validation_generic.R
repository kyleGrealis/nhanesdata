# run_validation_generic.R - Run cross-cycle comparison for any dataset
# Usage: Rscript inst/scripts/run_validation_generic.R DIQ
library(dplyr)
library(stringr)
library(tibble)

source("inst/scripts/validate_dataset.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) stop("Usage: Rscript run_validation_generic.R TABLE_NAME")
dataset <- toupper(args[1])

suffixes <- c("", "B", "C", "D", "E", "F", "G", "H", "I", "J", "L")
years <- c(1999, 2001, 2003, 2005, 2007, 2009, 2011, 2013, 2015, 2017, 2021)

message(sprintf("=== Loading cached %s codebooks ===", dataset))
inventory <- list()
for (i in seq_along(suffixes)) {
  s <- suffixes[i]
  table_code <- if (s == "") dataset else paste0(dataset, "_", s)
  cache_file <- file.path("inst/cache/codebooks", paste0(table_code, ".rds"))
  if (file.exists(cache_file)) {
    cached <- readRDS(cache_file)
    if (is.list(cached) && !is.data.frame(cached) && isTRUE(cached$.no_codebook)) {
      inventory[[table_code]] <- NULL
    } else {
      inventory[[table_code]] <- cached
      message(sprintf("  %s: %d variables", table_code, length(cached)))
    }
  }
}

message(sprintf("\n=== Cross-cycle comparison: %s ===", dataset))
comparison <- compare_variables(inventory)
saveRDS(comparison, file.path("inst/cache", paste0(tolower(dataset), "_comparison.rds")))

message("\n\n========== FULL RESULTS ==========")
if (nrow(comparison) > 0) {
  for (class_type in c("semantic_drift", "cosmetic_drift", "stable", "continuous", "single_cycle")) {
    subset <- comparison |> filter(classification == class_type) |> arrange(variable)
    if (nrow(subset) == 0) next
    message(sprintf("\n--- %s (%d variables) ---", toupper(class_type), nrow(subset)))
    for (i in seq_len(nrow(subset))) {
      row <- subset[i, ]
      detail_str <- if (nchar(row$details) > 400) paste0(substr(row$details, 1, 400), "...") else row$details
      message(sprintf("  %s (cycles: %d): %s", row$variable, row$n_cycles, detail_str))
    }
  }
}
message("\n=== Done ===")
