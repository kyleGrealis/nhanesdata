################################################################################
# Title: Combined Glycohemoglobin (HbA1c) Dataset
# Date: 2026-05-07
# Source datasets: lab10 (1999), l10 (2001-2003), ghb (2005-2021)
################################################################################

#### Purpose ####

# CDC changed the table name for glycohemoglobin (HbA1c) across NHANES eras:
#   - LAB10: 1999-2000
#   - L10:   2001-2002, 2003-2004
#   - GHB:   2005-2006 through 2021-2023
#
# All three contain the same core variable (LBXGH = glycohemoglobin %).
# This script combines them into one longitudinal dataset spanning 1999-2021
# so users don't need to know the era-specific table names.

#### Setup ####

library(dplyr)
library(nhanesdata)

#### Pull & Combine ####

lab10 <- nhanesdata::read_nhanes("lab10")
l10   <- nhanesdata::read_nhanes("l10")
ghb   <- nhanesdata::read_nhanes("ghb")

ghb_combined <- dplyr::bind_rows(lab10, l10, ghb) |>
  dplyr::arrange(year, seqn)

message(sprintf(
  "ghb_combined: %s rows, %d columns, cycles: %s",
  scales::comma(nrow(ghb_combined)),
  ncol(ghb_combined),
  paste(sort(unique(ghb_combined$year)), collapse = ", ")
))

#### Upload ####

nhanesdata:::nhanes_r2_upload(
  x = ghb_combined,
  name = "ghb_combined",
  bucket = "nhanes-data"
)
