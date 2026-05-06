################################################################################
# Title: Combined Fasting Glucose, Insulin & C-peptide Dataset
# Date: 2026-05-07
# Source datasets: lab10am (1999), l10am (2001-2003), glu (2005-2021)
################################################################################

#### Purpose ####

# CDC changed the table name for fasting glucose/insulin across NHANES eras:
#   - LAB10AM: 1999-2000
#   - L10AM:   2001-2002, 2003-2004
#   - GLU:     2005-2006 through 2021-2023
#
# Column name changes across eras:
#   - lbxglusi (1999-2003) -> lbdglusi (2005+): Glucose SI units (mmol/L)
#   - lbxinsi  (1999-2003) -> lbdinsi  (2005+): Insulin SI units (pmol/L)
#
# Variables that are era-specific (kept as-is, NA in other eras):
#   - wtsaf4yr: 4-year fasting weight (1999-2003 only)
#   - lbxcpsi:  C-peptide SI (1999-2003 only)
#   - phafsthr/phafstmn: Fasting hours/minutes (2005-2013 only)
#   - lbxin/lbdinsi: Insulin (dropped from GLU after 2013, moved to INS)
#
# This script harmonizes column names and combines into one longitudinal
# dataset spanning 1999-2021.

#### Setup ####

library(dplyr)
library(nhanesdata)

#### Pull ####

lab10am <- nhanesdata::read_nhanes("lab10am")
l10am   <- nhanesdata::read_nhanes("l10am")
glu     <- nhanesdata::read_nhanes("glu")

#### Harmonize column names ####

# Rename early-era SI columns to match the 2005+ naming convention
harmonize_early <- function(df) {
  if ("lbxglusi" %in% names(df) && !"lbdglusi" %in% names(df)) {
    df <- df |> dplyr::rename(lbdglusi = lbxglusi)
  }
  if ("lbxinsi" %in% names(df) && !"lbdinsi" %in% names(df)) {
    df <- df |> dplyr::rename(lbdinsi = lbxinsi)
  }
  df
}

lab10am <- harmonize_early(lab10am)
l10am   <- harmonize_early(l10am)

#### Combine ####

glu_combined <- dplyr::bind_rows(lab10am, l10am, glu) |>
  dplyr::arrange(year, seqn)

message(sprintf(
  "glu_combined: %s rows, %d columns, cycles: %s",
  scales::comma(nrow(glu_combined)),
  ncol(glu_combined),
  paste(sort(unique(glu_combined$year)), collapse = ", ")
))

# Column inventory
message("\nColumns: ", paste(names(glu_combined), collapse = ", "))

#### Upload ####

nhanesdata:::nhanes_r2_upload(
  x = glu_combined,
  name = "glu_combined",
  bucket = "nhanes-data"
)
