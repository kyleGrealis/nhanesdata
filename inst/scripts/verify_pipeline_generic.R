# verify_pipeline_generic.R - Pull and verify any dataset
# Usage: Rscript inst/scripts/verify_pipeline_generic.R DIQ
library(dplyr)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) stop("Usage: Rscript verify_pipeline_generic.R TABLE_NAME")
dataset <- tolower(args[1])

devtools::load_all()
source("inst/scripts/pull_nhanes.R")

message(sprintf("=== Pulling %s ===", toupper(dataset)))
data <- pull_nhanes(dataset, save = FALSE)

cache_file <- file.path("inst/cache/data", paste0(dataset, "_merged.rds"))
saveRDS(data, cache_file)

message(sprintf("\nMerged: %s rows, %d columns", scales::comma(nrow(data)), ncol(data)))
message(sprintf("Cycles: %s", paste(sort(unique(data$year)), collapse = ", ")))

# Identify categorical columns (character type, not year/seqn)
char_cols <- names(data)[sapply(data, is.character)]
char_cols <- setdiff(char_cols, c("year", "seqn"))

message(sprintf("\n=== Checking %d categorical variables ===", length(char_cols)))

for (var in char_cols) {
  vals_by_year <- data |>
    filter(!is.na(.data[[var]])) |>
    group_by(year) |>
    summarise(
      n = n(),
      unique_vals = paste(sort(unique(.data[[var]])), collapse = " | "),
      .groups = "drop"
    )

  if (nrow(vals_by_year) == 0) next

  message(sprintf("\n--- %s ---", toupper(var)))
  for (i in seq_len(nrow(vals_by_year))) {
    row <- vals_by_year[i, ]
    val_str <- if (nchar(row$unique_vals) > 150) {
      paste0(substr(row$unique_vals, 1, 150), "...")
    } else {
      row$unique_vals
    }
    message(sprintf("  %d (n=%s): %s", row$year, scales::comma(row$n), val_str))
  }
}

# Column type summary
message("\n=== Column type summary ===")
type_counts <- sapply(data, class) |> unlist() |> table()
for (nm in names(type_counts)) {
  message(sprintf("  %s: %d columns", nm, type_counts[nm]))
}

message("\n=== Done ===")
