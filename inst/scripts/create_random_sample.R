#!/usr/bin/env Rscript

# Random Sampling Script for NHANES Dataset Testing
#
# Purpose:
#   Select a stratified random sample of 20 datasets from datasets.yml
#   for testing the upload workflow before running full batch processing.
#
# Sampling Strategy:
#   - Proportional stratified sampling by category
#   - Reproducible (fixed seed)
#   - Saves results to CSV for workflow consumption
#
# Usage:
#   Rscript inst/scripts/create_random_sample.R

suppressPackageStartupMessages({
  library(yaml)
  library(dplyr)
  library(cli)
})

cli_h1("NHANES Dataset Random Sampling")

# Read datasets configuration
cli_alert_info("Reading datasets.yml...")
config_file <- "inst/extdata/datasets.yml"

if (!file.exists(config_file)) {
  cli_alert_danger("Configuration file not found: {config_file}")
  quit(status = 1)
}

datasets <- yaml::read_yaml(config_file)$datasets

# Convert to data frame
df <- tibble(
  name = sapply(datasets, function(x) x$name),
  description = sapply(datasets, function(x) x$description),
  category = sapply(datasets, function(x) x$category)
)

cli_alert_success("Loaded {nrow(df)} datasets")

# Show category distribution
category_counts <- df |>
  group_by(category) |>
  summarise(count = n(), .groups = "drop") |>
  arrange(category)

cli_h2("Category Distribution")
for (i in seq_len(nrow(category_counts))) {
  cat <- category_counts$category[i]
  cnt <- category_counts$count[i]
  cli_alert_info("{tools::toTitleCase(cat)}: {cnt} datasets")
}

# Stratified random sample (proportional to category sizes)
cli_h2("Generating Random Sample")
set.seed(2026)  # Reproducible
sample_size <- 20

# Calculate target sample sizes per category
total_n <- nrow(df)
target_sizes <- df |>
  group_by(category) |>
  summarise(n_cat = n(), .groups = "drop") |>
  mutate(target = ceiling(sample_size * n_cat / total_n))

# Sample from each category
sample_list <- list()
for (i in seq_len(nrow(target_sizes))) {
  cat <- target_sizes$category[i]
  n_sample <- target_sizes$target[i]
  cat_data <- df |> filter(category == cat)
  sample_list[[i]] <- cat_data |>
    slice_sample(n = min(n_sample, nrow(cat_data)))
}

sample_df <- bind_rows(sample_list) |>
  slice_sample(n = sample_size)  # Exactly 20

cli_alert_success("Selected {nrow(sample_df)} datasets")

# Show sample distribution
sample_counts <- sample_df |>
  group_by(category) |>
  summarise(count = n(), .groups = "drop") |>
  arrange(category)

cli_h2("Sample Distribution")
for (i in seq_len(nrow(sample_counts))) {
  cat <- sample_counts$category[i]
  cnt <- sample_counts$count[i]
  pct <- round(100 * cnt / sample_size, 1)
  cli_alert_info("{tools::toTitleCase(cat)}: {cnt} datasets ({pct}%)")
}

# Print sample list
cli_h2("Selected Datasets")
sample_df_sorted <- sample_df |>
  arrange(category, name)

for (i in seq_len(nrow(sample_df_sorted))) {
  cat <- sample_df_sorted$category[i]
  name <- sample_df_sorted$name[i]
  desc <- sample_df_sorted$description[i]
  cli_alert("{name} ({cat}): {desc}")
}

# Save to CSV
output_file <- "inst/extdata/test_sample.csv"
write.csv(sample_df, output_file, row.names = FALSE)
cli_alert_success("Sample saved to: {output_file}")

cli_rule()
cli_alert_info("Use with: Rscript inst/scripts/workflow_update.R --sample")
