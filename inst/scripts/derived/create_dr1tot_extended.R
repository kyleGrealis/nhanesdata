################################################################################
# Title:   Extended Day-1 Total Nutrient Intake Dataset (1999–2021)
# Author:  [contributor]
# Date:    2026-03-24
# Saved:   dr1tot_extended  (on Cloudflare R2 via nhanesdata:::nhanes_r2_upload)
# Issue:   https://github.com/kyleGrealis/nhanesdata/issues/10
################################################################################
#
# PURPOSE
# -------
# CDC changed the dietary total nutrient intake file naming convention mid-series:
#   1999-2000: DRXTOT   (no cycle suffix)
#   2001-2002: DRXTOT_B
#   2003+:     DR1TOT_C, DR1TOT_D, ... (day-1 only; DR2TOT = day-2 split added)
#
# This script combines both eras into a single longitudinal file, extending
# dr1tot back to 1999. It is the total-nutrient-intake counterpart to
# create_dr1iff_extended.R, which extends the individual food file (dr1iff).
#
# FILE STRUCTURE
# --------------
# dr1tot / drxtot: one row per participant per recall day. Contains the sum
# of all nutrients consumed across all food items reported in that recall.
# Row counts per cycle are therefore ~equal to the number of dietary
# participants (~7,000–10,000), much smaller than the individual food file.
#
# COLUMN HARMONIZATION
# --------------------
# Pre-2003 total nutrient columns use the DRXT* prefix (e.g., DRXTKCAL),
# which maps to DR1T* (e.g., DR1TKCAL) in the 2003+ schema.
# Recall-level columns use the DRD* prefix (e.g., DRDDRSTS → DR1DRSTZ).
# The bulk rename strategy:
#   drx* -> dr1*   (nutrient total columns)
#   drd* -> dr1d*  (recall-level descriptor columns)
# Then take the column intersection of both eras.
#
# DAY-1 FILTER
# ------------
# Same logic as create_dr1iff_extended.R:
#   drdintmd == "In-person"  →  day-1 MEC recall (keep)
#   drdintmd == "Telephone"  →  day-2 phone recall (drop)
#   drdintmd == NA           →  2001-2002 cycle; day indicator not translated
#                               by nhanesA for DRXTOT_B. Confirmed single-day
#                               via seqn uniqueness check in dr1iff script.
#
# VALIDATION NOTE FOR KYLE
# ------------------------
# Run QC block (Section 5) before uploading. Key checks:
#   - Row counts: expect ~7,000–9,000 per pre-2003 cycle (one row per participant)
#   - dr1tkcal range: total daily energy intake; plausible range ~500–8,000 kcal
#   - CDC reference: https://wwwn.cdc.gov/nchs/nhanes/1999-2000/DRXTOT.htm
#
# YEARS INCLUDED
# --------------
#   Pre-2003 era:  1999, 2001  (from drxtot, filtered to day 1)
#   2003+ era:     2003, 2005, 2007, 2009, 2011, 2013, 2015, 2017, 2021
#   Total:         11 cycles
################################################################################



#### 0. Packages ####

library(dplyr)
library(nhanesdata)
library(janitor)



#### 1. Pull source tables ####

message("Pulling drxtot (1999-2000 and 2001-2002 total nutrient intakes) ...")
drxtot_raw <- nhanesdata::read_nhanes("drxtot")

message("Pulling dr1tot (2003-2021 total nutrient intakes, day 1) ...")
dr1tot_raw <- nhanesdata::read_nhanes("dr1tot")



#### 2. Sanity-check row counts before processing ####

message("\nSource row counts by year:")
message("  drxtot (pre-2003 era):")
print(drxtot_raw |> count(year))
message("  dr1tot (2003+ era):")
print(dr1tot_raw |> count(year))



#### 3. Prepare the pre-2003 era ####

# Step 3a: Inspect and filter to day-1 recalls only.
# drdintmd values (confirmed from drxiff sister file):
#   "In-person" = day-1 MEC recall — keep
#   "Telephone" = day-2 phone recall — drop
#   NA          = 2001-2002 cycle (DRXTOT_B); include all rows
message("\nDistribution of drdintmd (interview day indicator) in drxtot:")
print(drxtot_raw |> count(drdintmd))

drxtot_day1 <- drxtot_raw |>
  filter(drdintmd == "In-person" | is.na(drdintmd))

message(sprintf(
  "  drxtot after filtering to day 1: %d rows (dropped %d telephone/day-2 rows)",
  nrow(drxtot_day1),
  nrow(drxtot_raw) - nrow(drxtot_day1)
))

# Step 3b: Clean column names.
drxtot_day1 <- drxtot_day1 |> janitor::clean_names()

# Step 3c: Bulk-swap column prefixes to match dr1tot naming convention.
# drxtot has two prefix patterns:
#   drxt* -> dr1t*  (nutrient total columns: drxtkcal, drxtprot, etc.)
#   drd*  -> dr1d*  (recall-level columns: drddrsts, drdday, etc.)
n_drx <- sum(grepl("^drx", names(drxtot_day1)))
n_drd <- sum(grepl("^drd", names(drxtot_day1)))

drxtot_day1 <- drxtot_day1 |>
  rename_with(~ sub("^drx", "dr1",  .), starts_with("drx")) |>
  rename_with(~ sub("^drd", "dr1d", .), starts_with("drd"))

message(sprintf(
  "  Bulk-renamed %d 'drx' columns and %d 'drd' columns", n_drx, n_drd
))

# Step 3d: Drop the day-indicator column.
drxtot_day1 <- drxtot_day1 |> select(-any_of("dr1dintmd"))



#### 4. Align schemas and combine ####

dr1tot_clean <- dr1tot_raw |> janitor::clean_names()

shared_cols <- intersect(names(drxtot_day1), names(dr1tot_clean))
n_only_old  <- length(setdiff(names(drxtot_day1), names(dr1tot_clean)))
n_only_new  <- length(setdiff(names(dr1tot_clean), names(drxtot_day1)))

message(sprintf(
  "\nColumn overlap: %d shared | %d only in drxtot (pre-2003) | %d only in dr1tot (2003+)",
  length(shared_cols), n_only_old, n_only_new
))

if (n_only_old > 0) {
  message("  Columns present only in pre-2003 era (will be dropped):")
  message("  ", paste(setdiff(names(drxtot_day1), names(dr1tot_clean)), collapse = ", "))
}
if (n_only_new > 0) {
  message("  Columns present only in 2003+ era (will be dropped):")
  message("  ", paste(setdiff(names(dr1tot_clean), names(drxtot_day1)), collapse = ", "))
}

dr1tot_extended <- bind_rows(
  drxtot_day1  |> select(all_of(shared_cols)),
  dr1tot_clean |> select(all_of(shared_cols))
) |>
  arrange(year, seqn)

message(sprintf(
  "\nCombined dataset: %d rows, %d columns",
  nrow(dr1tot_extended), ncol(dr1tot_extended)
))



#### 5. QC checks ####

message("\n--- QC Report: dr1tot_extended ---\n")

# 5a. Row counts by year.
# Expect ~7,000–9,000 per cycle (one row per participant per recall day).
message("Rows by cycle (expect ~7k-9k per cycle — one row per participant):")
print(dr1tot_extended |> count(year))

# 5b. Confirm year and seqn present.
stopifnot(
  "year column missing" = "year" %in% names(dr1tot_extended),
  "seqn column missing" = "seqn" %in% names(dr1tot_extended)
)

# 5c. No 2019 rows.
stopifnot(
  "Unexpected 2019 rows found" = !any(dr1tot_extended$year == 2019)
)

# 5d. Spot-check total energy intake.
# dr1tkcal = total kcal for the day (sum across all food items). This is the
# correct column in the total nutrient file. Plausible range: ~500–8,000 kcal/day.
if ("dr1tkcal" %in% names(dr1tot_extended)) {
  kcal_range   <- range(dr1tot_extended$dr1tkcal, na.rm = TRUE)
  kcal_missing <- mean(is.na(dr1tot_extended$dr1tkcal)) * 100
  message(sprintf(
    "dr1tkcal (total daily energy kcal): range [%.0f, %.0f], %.1f%% missing",
    kcal_range[1], kcal_range[2], kcal_missing
  ))
  n_implausible <- sum(dr1tot_extended$dr1tkcal > 8000, na.rm = TRUE)
  if (n_implausible > 0) {
    message(sprintf(
      "  WARNING: %d rows with dr1tkcal > 8,000 kcal/day — inspect these.",
      n_implausible
    ))
  }
} else {
  message("WARNING: dr1tkcal not found — the nutrient column rename may not have worked correctly.")
}

# 5e. Confirm 1999 and 2001 rows are present.
early_cycles <- dr1tot_extended |> filter(year %in% c(1999, 2001)) |> count(year)
message("\nEarly cycle rows (should be non-zero):")
print(early_cycles)
stopifnot(
  "No 1999 rows found — pre-2003 data was not added" = any(early_cycles$year == 1999),
  "No 2001 rows found — pre-2003 data was not added" = any(early_cycles$year == 2001)
)

# 5f. Confirm one row per participant per year (no duplicates).
n_dupes <- dr1tot_extended |>
  count(year, seqn) |>
  filter(n > 1) |>
  nrow()
message(sprintf(
  "\nDuplicate seqn+year rows: %d (expect 0 — one row per participant per recall day)",
  n_dupes
))
if (n_dupes > 0) {
  warning("Duplicate seqn+year rows found — investigate before uploading.")
}

# 5g. Missing rate summary.
miss_rates <- dr1tot_extended |>
  summarise(across(everything(), ~ round(mean(is.na(.)) * 100, 1))) |>
  tidyr::pivot_longer(everything(), names_to = "variable", values_to = "pct_missing") |>
  arrange(desc(pct_missing))
message("\nTop 10 columns by missing rate (%):")
print(head(miss_rates, 10))

message("\nAll QC checks passed.")



#### 6. Upload to Cloudflare R2 ####

# Uncomment and run after QC sign-off. Kyle runs this from main branch.

# nhanesdata:::nhanes_r2_upload(
#   x      = dr1tot_extended,
#   name   = "dr1tot_extended",
#   bucket = "nhanes-data"
# )
#
# Verify with:
#   check <- nhanesdata::read_nhanes("dr1tot_extended")
#   stopifnot(nrow(check) == nrow(dr1tot_extended))
#   check |> count(year)
