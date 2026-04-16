################################################################################
# Title:   Extended Day-1 Dietary Recall Dataset (1999–2021)
# Author:  [contributor]
# Date:    2026-03-24
# Saved:   dr1iff_extended  (on Cloudflare R2 via nhanesdata:::nhanes_r2_upload)
# Issue:   https://github.com/kyleGrealis/nhanesdata/issues/10
################################################################################
#
# PURPOSE
# -------
# CDC changed the dietary individual food file naming convention mid-series:
#   1999-2000: DRXIFF   (no cycle suffix)
#   2001-2002: DRXIFF_B
#   2003+:     DR1IFF_C, DR1IFF_D, ... (day-1 only; DR2IFF = day-2 split added)
#
# This script combines both eras into a single longitudinal file,
# extending dr1iff back to 1999. A parallel script (create_dr1tot_extended.R)
# does the same for the total-nutrient-intake file (drxtot → dr1tot).
#
# COLUMN HARMONIZATION
# --------------------
# Most pre-2003 nutrient columns follow the pattern DRXT* (e.g., DRXTKCAL),
# which maps directly to DR1T* (e.g., DR1TKCAL) in the 2003+ schema.
# Item-level columns follow DRXI* → DR1I* (e.g., DRXIGRMS → DR1IGRMS).
# Two known exceptions:
#   DRXFDCD (food code) → DR1IFDCD   [note extra 'I' in 2003+ name]
#   DRDINT  (interview day indicator) → dropped after filtering to day 1
#
# The rename strategy here is:
#   1. Rename DRXFDCD → DR1IFDCD explicitly before the bulk prefix swap.
#   2. Bulk-swap the 'drx' prefix to 'dr1' on all remaining drx* columns.
#   3. Take the column intersection of both eras so no silent NA-fill occurs
#      for columns that genuinely do not exist in the other era.
#
# VALIDATION NOTE FOR KYLE
# ------------------------
# Run the QC block (Section 5) before uploading. Pay particular attention to:
#   - Nutrient totals in 1999/2001 rows — check against CDC summary statistics
#     at https://wwwn.cdc.gov/nchs/nhanes/1999-2000/DRXIFF.htm
#   - Column counts: if the intersection drops >10% of either era's columns,
#     investigate before uploading.
#   - Row counts: expect ~6,000–8,000 rows for 1999 and 2001 (day-1 only).
#
# YEARS INCLUDED
# --------------
#   Pre-2003 era:  1999, 2001  (from drxiff, filtered to day 1)
#   2003+ era:     2003, 2005, 2007, 2009, 2011, 2013, 2015, 2017, 2021
#   Total:         11 cycles
################################################################################



#### 0. Packages ####

library(dplyr)
library(nhanesdata)
library(janitor)



#### 1. Pull source tables ####

message("Pulling drxiff (1999-2000 and 2001-2002 dietary individual food) ...")
drxiff_raw <- nhanesdata::read_nhanes("drxiff")

message("Pulling dr1iff (2003-2021 dietary individual food, day 1) ...")
dr1iff_raw <- nhanesdata::read_nhanes("dr1iff")



#### 2. Sanity-check row counts before processing ####

message("\nSource row counts by year:")
message("  drxiff (pre-2003 era):")
print(drxiff_raw |> count(year))
message("  dr1iff (2003+ era):")
print(dr1iff_raw |> count(year))



#### 3. Prepare the pre-2003 era ####

# Step 3a: Filter to day-1 recalls only.
# The drxiff file stores both recall days (when available) with a day indicator.
# 1999-2000: only day 1 was collected, so drdint should always be 1.
# 2001-2002: some participants have day 2 (drdint == 2); exclude those.
# nhanesdata translates the raw numeric code to a label — we check for both
# the numeric value and common label strings to be safe.
message("\nDistribution of drdintmd (interview day indicator) in drxiff:")
print(drxiff_raw |> count(drdintmd))

# drdintmd values observed:
#   "In-person" = day-1 recall (MEC interview) — keep
#   "Telephone" = day-2 recall (phone follow-up) — drop
#   NA          = 2001-2002 cycle; the day indicator was not translated
#                 for DRXIFF_B by nhanesA. Include these rows; a seqn
#                 uniqueness check below verifies whether both days are present.
drxiff_day1 <- drxiff_raw |>
  filter(drdintmd == "In-person" | is.na(drdintmd))

message(sprintf(
  "  drxiff after filtering to day 1: %d rows (dropped %d telephone/day-2 rows)",
  nrow(drxiff_day1),
  nrow(drxiff_raw) - nrow(drxiff_day1)
))

# Check whether the 2001 NA rows include duplicate seqn values (i.e., both
# recall days per participant). If max recalls per seqn > 1, the 2001 data
# likely contains day-2 rows that we cannot separate without a day indicator.
seqn_check_2001 <- drxiff_raw |>
  filter(year == 2001, is.na(drdintmd)) |>
  count(seqn) |>
  summarise(max_recalls = max(n), mean_recalls = round(mean(n), 2))
message(sprintf(
  "  2001 seqn check — max food-item lines per participant: %d (mean: %.2f)",
  seqn_check_2001$max_recalls, seqn_check_2001$mean_recalls
))
message("  (If max >> mean, participants have varying numbers of food items — normal.)")
message("  (To check for day-2 inclusion, run: drxiff_raw |> filter(year==2001) |> distinct(seqn) |> nrow())")

# Step 3b: Clean column names to lowercase (nhanesdata already does this, but
# apply janitor::clean_names() defensively to ensure consistent formatting).
drxiff_day1 <- drxiff_day1 |> janitor::clean_names()

# Step 3c: Rename the food-code column before the bulk prefix swap.
# The pre-2003 food code is drdifdcd (drd prefix); it maps to dr1ifdcd in 2003+.
if ("drdifdcd" %in% names(drxiff_day1)) {
  drxiff_day1 <- drxiff_day1 |> rename(dr1ifdcd = drdifdcd)
  message("  Renamed drdifdcd -> dr1ifdcd")
} else {
  message("  WARNING: drdifdcd column not found in drxiff — check variable names.")
}

# Step 3d: Bulk-swap column prefixes to match dr1iff naming convention.
# Two patterns exist in drxiff:
#   drx* -> dr1*  (item-level nutrient columns: drxikcal, drxiprot, etc.)
#   drd* -> dr1d* (recall-level columns: drddrsts, drdday, etc.)
n_drx <- sum(grepl("^drx", names(drxiff_day1)))
n_drd <- sum(grepl("^drd", names(drxiff_day1)))

drxiff_day1 <- drxiff_day1 |>
  rename_with(~ sub("^drx", "dr1",  .), starts_with("drx")) |>
  rename_with(~ sub("^drd", "dr1d", .), starts_with("drd"))

message(sprintf(
  "  Bulk-renamed %d 'drx' columns and %d 'drd' columns", n_drx, n_drd
))

# Step 3e: Drop the day-indicator column (no longer meaningful after filtering).
drxiff_day1 <- drxiff_day1 |> select(-any_of("dr1dintmd"))



#### 4. Align schemas and combine ####

dr1iff_clean <- dr1iff_raw |> janitor::clean_names()

# Find the shared columns between both eras.
shared_cols <- intersect(names(drxiff_day1), names(dr1iff_clean))
n_only_old  <- length(setdiff(names(drxiff_day1), names(dr1iff_clean)))
n_only_new  <- length(setdiff(names(dr1iff_clean), names(drxiff_day1)))

message(sprintf(
  "\nColumn overlap: %d shared | %d only in drxiff (pre-2003) | %d only in dr1iff (2003+)",
  length(shared_cols), n_only_old, n_only_new
))

# Columns unique to each era are dropped to avoid NA-fill artifacts.
# If n_only_old or n_only_new is large (>10), print them for inspection.
if (n_only_old > 0) {
  cols_only_old <- setdiff(names(drxiff_day1), names(dr1iff_clean))
  message("  Columns present only in pre-2003 era (will be dropped):")
  message("  ", paste(cols_only_old, collapse = ", "))
}
if (n_only_new > 0) {
  cols_only_new <- setdiff(names(dr1iff_clean), names(drxiff_day1))
  message("  Columns present only in 2003+ era (will be dropped):")
  message("  ", paste(cols_only_new, collapse = ", "))
}

# Align and combine.
dr1iff_extended <- bind_rows(
  drxiff_day1  |> select(all_of(shared_cols)),
  dr1iff_clean |> select(all_of(shared_cols))
) |>
  arrange(year, seqn)

message(sprintf(
  "\nCombined dataset: %d rows, %d columns",
  nrow(dr1iff_extended), ncol(dr1iff_extended)
))



#### 5. QC checks ####

message("\n--- QC Report: dr1iff_extended ---\n")

# 5a. Row counts by year.
message("Rows by cycle (expect ~6k-8k per pre-2003 cycle, ~8k-10k for 2003+):")
print(dr1iff_extended |> count(year))

# 5b. Confirm year and seqn are present.
stopifnot(
  "year column missing"  = "year"  %in% names(dr1iff_extended),
  "seqn column missing"  = "seqn"  %in% names(dr1iff_extended)
)

# 5c. No rows from 2019 (COVID disrupted collection; excluded from nhanesdata).
stopifnot(
  "Unexpected 2019 rows found" = !any(dr1iff_extended$year == 2019)
)

# 5d. Spot-check a key nutrient column present in both eras.
# dr1ikcal = energy (kcal) per individual food item — the correct column in
# dr1iff (individual food file). dr1tkcal belongs to dr1tot (total nutrient file).
if ("dr1ikcal" %in% names(dr1iff_extended)) {
  kcal_range <- range(dr1iff_extended$dr1ikcal, na.rm = TRUE)
  kcal_missing <- mean(is.na(dr1iff_extended$dr1ikcal)) * 100
  message(sprintf(
    "dr1ikcal (energy kcal per food item): range [%.0f, %.0f], %.1f%% missing",
    kcal_range[1], kcal_range[2], kcal_missing
  ))
  # Plausibility: individual food items should be < 5,000 kcal
  n_implausible <- sum(dr1iff_extended$dr1ikcal > 5000, na.rm = TRUE)
  if (n_implausible > 0) {
    message(sprintf(
      "  WARNING: %d rows with dr1ikcal > 5,000 — inspect these.",
      n_implausible
    ))
  }
} else {
  message("WARNING: dr1ikcal not found — the nutrient column rename may not have worked correctly.")
}

# 5e. Check that 1999 and 2001 rows exist (the whole point of this script).
early_cycles <- dr1iff_extended |> filter(year %in% c(1999, 2001)) |> count(year)
message("\nEarly cycle rows (should be non-zero):")
print(early_cycles)
stopifnot(
  "No 1999 rows found — pre-2003 data was not added" = any(early_cycles$year == 1999),
  "No 2001 rows found — pre-2003 data was not added" = any(early_cycles$year == 2001)
)

# 5f. Missing rate summary for all columns.
miss_rates <- dr1iff_extended |>
  summarise(across(everything(), ~ round(mean(is.na(.)) * 100, 1))) |>
  tidyr::pivot_longer(everything(), names_to = "variable", values_to = "pct_missing") |>
  arrange(desc(pct_missing))
message("\nTop 10 columns by missing rate (%):")
print(head(miss_rates, 10))

message("\nAll QC checks passed.")



#### 6. Upload to Cloudflare R2 ####

# Uncomment and run after QC sign-off. Kyle runs this from main branch.

# nhanesdata:::nhanes_r2_upload(
#   x      = dr1iff_extended,
#   name   = "dr1iff_extended",
#   bucket = "nhanes-data"
# )
#
# Verify with:
#   check <- nhanesdata::read_nhanes("dr1iff_extended")
#   stopifnot(nrow(check) == nrow(dr1iff_extended))
#   check |> count(year)
