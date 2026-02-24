# NHANES Dataset Discovery Script
#
# Purpose:
#   Query nhanesA package to discover all available NHANES datasets across
#   multiple survey cycles (1999-2017). Used to audit and update the
#   datasets.yml configuration file.
#
# Output:
#   - CSV file with all unique dataset base names and descriptions
#   - Excludes surplus samples, pooled samples, and special samples
#
# Created: 2026-02-23
# Last updated: 2026-02-23
#
# Usage:
#   source("inst/scripts/audit_nhanes_datasets.R")
#   # Output saved to: inst/extdata/audit_all_nhanes_tables.csv

library(dplyr)

# Survey cycles to query (1999-2017)
years <- c(1999, 2001, 2003, 2005, 2007, 2009, 2011, 2013, 2015, 2017)

# Data categories in NHANES
categories <- c("LAB", "Q", "EXAM", "DIET")

# Initialize list to store results
all_tables <- list()

# Query nhanesA for all tables across all years and categories
cat("Querying nhanesA for all NHANES datasets...\n")
for (y in years) {
  cat("  Year:", y, "\n")
  for (cat in categories) {
    tryCatch({
      tables <- nhanesA::nhanesTables(cat, y)
      if (nrow(tables) > 0) {
        tables$year <- y
        tables$category <- cat
        all_tables[[paste(y, cat)]] <- tables
      }
    }, error = function(e) {
      # Some year/category combinations may not exist
      NULL
    })
  }
}

# Combine all results
combined <- bind_rows(all_tables)

# Extract base table name (remove cycle suffix like _A, _B, _J, etc.)
# Suffixes correspond to survey cycles:
#   _A = 1999-2000, _B = 2001-2002, _C = 2003-2004, etc.
combined$base_name <- tolower(gsub("_[A-Z]$", "", combined$Data.File.Name))

# Filter out datasets we don't want to include:
# 1. Surplus samples (ss* prefix) - require special access
# 2. Pooled samples (*pol suffix) - different analysis requirements
# 3. Pool support files (contains "pool" in name)
# 4. Pandemic prefix (p_*) - special COVID-era data
# 5. Special samples (_s suffix) - limited availability
# 6. Raw data files (*raw suffix) - unprocessed data
# 7. Old naming conventions from 1999-2001 that duplicate newer tables
filtered <- combined |>
  filter(!grepl("^ss", base_name)) |>
  filter(!grepl("pol$", base_name)) |>
  filter(!grepl("pool", base_name)) |>
  filter(!grepl("^p_", base_name)) |>
  filter(!grepl("_s$", base_name)) |>
  filter(!grepl("raw$", base_name)) |>
  filter(
    !grepl("^l[0-9]+_", base_name) &
    !grepl("^lab[0-9]+$", base_name) &
    !base_name %in% c("l02hbs", "l02hpa", "l02hpa_a", "l03", "l04per",
                      "l04voc", "l05")
  )

# Map NHANES category codes to our package category names
filtered <- filtered |>
  mutate(yaml_category = case_when(
    category == "Q" ~ "questionnaire",
    category == "LAB" ~ "laboratory",
    category == "EXAM" ~ "examination",
    category == "DIET" ~ "dietary",
    TRUE ~ category
  )) |>
  arrange(category, base_name)

# Get unique datasets (one row per base_name)
unique_tables <- filtered |>
  group_by(base_name) |>
  slice(1) |>
  ungroup() |>
  arrange(yaml_category, base_name) |>
  select(base_name, Data.File.Description, yaml_category, category)

# Save results
output_file <- "inst/extdata/audit_all_nhanes_tables.csv"
write.csv(unique_tables, output_file, row.names = FALSE)

# Print summary
cat("\n=== AUDIT SUMMARY ===\n")
cat("Total unique datasets found:", nrow(unique_tables), "\n\n")

cat("Breakdown by category:\n")
summary_table <- unique_tables |>
  count(yaml_category) |>
  arrange(desc(n))
print(summary_table)

cat("\nOutput saved to:", output_file, "\n")

# Sample a few datasets to verify
cat("\nSample datasets:\n")
print(head(unique_tables |> select(base_name, Data.File.Description), 10))
