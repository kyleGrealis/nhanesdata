################################################################################
# Title:   Expanded Base NHANES Dataset (1999–2021)
# Author:  [contributor]
# Date:    2026-03-29
# Saved:   base_1999_2021  (on Cloudflare R2 via nhanesdata:::nhanes_r2_upload)
################################################################################
#
# PURPOSE
# -------
# This script creates a single, wide, analysis-ready base dataset covering
# all NHANES cycles from 1999 through 2021 (11 cycles). Every study-specific
# script should start with read_nhanes("base_1999_2021"), filter to the cycles
# and age range it needs, and then join in its own exposure/outcome tables.
#
# TABLES PULLED
# -------------
#   demo      – Demographics, survey design, weights, pregnancy status
#   hiq       – Health insurance
#   smq       – Smoking
#   alq       – Alcohol use
#   paq       – Physical activity
#   bmx       – Body measures (BMI)
#   bpq       – Blood pressure / cholesterol questionnaire (self-report)
#   bpx       – Blood pressure, auscultatory readings (1999–2017)
#   bpxo      – Blood pressure, oscillometric readings (2017+; only source 2021)
#   diq       – Diabetes questionnaire
#   tchol     – Total cholesterol (lab)
#   ocq       – Occupation questionnaire
#   duq       – Drug use questionnaire (substance use / cannabis)
#   mortality – NCHS Linked Mortality File (1999–2018 surveys; follow-up through
#               Dec 31, 2019). 2021 participants will have NA for all mortality
#               variables — they are not yet included in the public-use LMF.
#
# DERIVED VARIABLES (all in base_small select at end)
# ---------------------------------------------------
#   race_ethnicity, education, income_cat, pir (continuous),
#   marital_status, nativity, has_health_ins,
#   smoking_status, alcohol_status, alcohol_current,
#   total_met_min, pa_level, phys_active,
#   bmi (continuous), bmi_cat,
#   mean_sbp, mean_dbp, hypertension,
#   diabetes, hyperlipidemia
#
# YEARS INCLUDED
# --------------
# 11 cycles: 1999, 2001, 2003, 2005, 2007, 2009, 2011, 2013, 2015, 2017, 2021
# (2019-2020 excluded: COVID-19 disrupted data collection; NHANES was
#  redesigned as a 3-year cycle starting in 2021)
#
# KEY DATA LIMITATIONS (by module)
# ---------------------------------
# BPX/BPXO   – Auscultatory BPX discontinued after 2017; 2021 uses oscillometric
#               BPXO only. Readings are coalesced in Section 4. Oscillometric
#               and auscultatory values are not perfectly equivalent — consider
#               a sensitivity analysis restricting to 1999–2017 if comparability
#               across measurement methods is a concern.
# TCHOL       – Available 2005+ only (earlier cycles used l13/l13_b/l13_c).
# PAQ         – The paq605/pad615 variable series used here was introduced in
#               2007–2008. Cycles 1999–2006 used different variable names not
#               harmonized here, and the series was removed again in 2017–2018
#               and 2021. total_met_min is NA by design for year==1999, 2001,
#               2003, 2005, 2017, and 2021. Valid data: 2007–2015 only.
# ALQ         – Not collected 1999–2000; adults 20+ only → high structural
#               missingness in the full sample.
# DUQ         – Not available for 1999, 2001, or 2003 (NA by design).
#               1999: not collected. 2001 (DUQ_B) and 2003 (DUQ_C): collected
#               but NCHS-restricted (sensitive data); absent from nhanesdata.
#               Public DUQ data begins with the 2005–2006 cycle.
#               Age eligibility varies by cycle:
#                 20–59 (2005–2006), 18–69 (2007–2010), 18–59 (2011–2021).
#               Participants outside the eligible age range have NA.
#               duq230 response scale shifted in 2007–2008 — interpret across
#               cycles with caution.
# OCQ         – ocq670 (work schedule) collected 2013+ only; NA by design for
#               1999–2011. ocq180 (hours/week) available all cycles for
#               participants who worked in past 12 months; NA by design for
#               those who did not work (unemployed, retired, etc.).
# MORTALITY   – LMF covers 1999–2018 survey participants; follow-up through
#               Dec 31, 2019. All 2021 participants have NA for mortality
#               variables. eligstat==2 = age <18, ineligible for linkage.
#               diab_mort and htn_mort are contributing causes on the death
#               certificate — they are DISTINCT from the comorbidity variables
#               diabetes and hypertension. Downstream scripts should filter to
#               eligstat==1 before constructing survival outcomes.
#               ucod_leading codes: 1=heart disease, 2=cancer, 3=COPD,
#               4=accidents, 5=stroke, 6=Alzheimer's, 7=diabetes, 8=flu/pneumonia,
#               9=nephritis, 10=all other. Derive all-cause, CVD, and cancer
#               mortality outcomes in study-specific scripts, not here.
# WEIGHTS     – The 2021 3-year cycle provides a proportionally adjusted
#               2-year-equivalent wtmec2yr for pooled analysis with earlier
#               cycles. Confirm with Kyle that nhanesdata stores the adjusted
#               (not raw 3-year) weight before using in pooled analyses.
#
# HARMONIZATION NOTES
# -------------------
# Several DEMO variables changed names or response-option wording across cycles.
# Key issues handled here:
#   income  – indhhinc (1999–2006) vs indhhin2 (2007+): coalesced into one
#             categorical variable; indfmpir (PIR) used as continuous income.
#   nativity – dmdborn/dmdborn2/dmdborn4 changed labels across cycles; we use
#              the cleaned nhanesdata label strings (case_when on text).
#   race    – ridreth3 (Asian category) only exists 2011+; ridreth1 used as
#             fallback.
#   BPX/BPXO – auscultatory (bpxsy*/bpxdi*) coalesced with oscillometric
#               (bpxosy*/bpxodi*) to handle the 2021 measurement transition.
################################################################################



#### 0. Packages ####

library(dplyr)
library(stringr)
library(forcats)
library(nhanesdata)
library(janitor)



#### 1. Pull NHANES tables ####

years <- c(1999, 2001, 2003, 2005, 2007, 2009, 2011, 2013, 2015, 2017, 2021)

message("Pulling tables from Cloudflare R2 ...")

demo  <- nhanesdata::read_nhanes("demo")      |> filter(year %in% years)
hiq   <- nhanesdata::read_nhanes("hiq")       |> filter(year %in% years)
smq   <- nhanesdata::read_nhanes("smq")       |> filter(year %in% years)
alq   <- nhanesdata::read_nhanes("alq")       |> filter(year %in% years)
paq   <- nhanesdata::read_nhanes("paq")       |> filter(year %in% years)
bmx   <- nhanesdata::read_nhanes("bmx")       |> filter(year %in% years)
bpq   <- nhanesdata::read_nhanes("bpq")       |> filter(year %in% years)
bpx   <- nhanesdata::read_nhanes("bpx")       |> filter(year %in% years)
bpxo  <- nhanesdata::read_nhanes("bpxo")      |> filter(year %in% years)
diq   <- nhanesdata::read_nhanes("diq")       |> filter(year %in% years)
tchol <- nhanesdata::read_nhanes("tchol")     |> filter(year %in% years)
ocq   <- nhanesdata::read_nhanes("ocq")       |> filter(year %in% years)
duq   <- nhanesdata::read_nhanes("duq")       |> filter(year %in% years)

# Rename mortality contributing-cause columns before join to avoid collision
# with the comorbidity variables diabetes and hypertension derived in Section 4.
mort  <- nhanesdata::read_nhanes("mortality") |>
  filter(year %in% years) |>
  rename(diab_mort = diabetes, htn_mort = hyperten)



#### 2. Sanity-check row counts before joining ####
# Expected: ~9,000–11,000 rows per 2-year cycle; ~10,000–12,000 for 2021
# (3-year cycle). mort will show rows for 1999–2017 only (~10 cycles);
# the absence of 2021 rows in mort is expected — not a join error.

message("\nRow counts by table and year before join:")
for (tbl_name in c("demo", "hiq", "smq", "alq", "paq", "bmx", "bpq",
                   "bpx", "bpxo", "diq", "tchol", "ocq", "duq", "mort")) {
  tbl    <- get(tbl_name)
  counts <- tbl |> count(year) |> pull(n) |> paste(collapse = " / ")
  message(sprintf("  %-6s  years %s", tbl_name, counts))
}



#### 3. Join tables ####

base <- demo |>
  janitor::clean_names() |>
  left_join(janitor::clean_names(hiq),   by = c("year", "seqn")) |>
  left_join(janitor::clean_names(smq),   by = c("year", "seqn")) |>
  left_join(janitor::clean_names(alq),   by = c("year", "seqn")) |>
  left_join(janitor::clean_names(paq),   by = c("year", "seqn")) |>
  left_join(janitor::clean_names(bmx),   by = c("year", "seqn")) |>
  left_join(janitor::clean_names(bpq),   by = c("year", "seqn")) |>
  left_join(janitor::clean_names(bpx),   by = c("year", "seqn")) |>
  left_join(janitor::clean_names(bpxo),  by = c("year", "seqn")) |>
  left_join(janitor::clean_names(diq),   by = c("year", "seqn")) |>
  left_join(janitor::clean_names(tchol), by = c("year", "seqn")) |>
  left_join(janitor::clean_names(ocq),   by = c("year", "seqn")) |>
  left_join(janitor::clean_names(duq),   by = c("year", "seqn")) |>
  left_join(janitor::clean_names(mort),  by = c("year", "seqn"))

# Confirm no duplicate seqn+year rows (would indicate a join problem)
stopifnot(
  "Duplicate seqn+year rows found after join — check for duplicate keys in a source table." =
    !any(duplicated(base[, c("seqn", "year")]))
)

message(sprintf("\nJoined dataset: %d rows, %d columns", nrow(base), ncol(base)))



#### 4. Derived variables ####

base <- base |>
  mutate(

    # -------------------------------------------------------------------------
    # BPX / BPXO HARMONIZATION
    # Auscultatory BPX (bpxsy*/bpxdi*) was discontinued after 2017–2018.
    # The 2021 cycle uses oscillometric BPXO (bpxosy*/bpxodi*) only.
    # Coalesce so that downstream blood pressure logic works uniformly:
    #   1999–2017: bpxsy*/bpxdi* populated → coalesce returns auscultatory value.
    #   2021:      bpxsy*/bpxdi* are NA    → coalesce returns oscillometric value.
    # These coalesced columns are intermediate — not retained in base_small.
    # -------------------------------------------------------------------------
    bpxsy1 = coalesce(bpxsy1, bpxosy1),
    bpxsy2 = coalesce(bpxsy2, bpxosy2),
    bpxsy3 = coalesce(bpxsy3, bpxosy3),
    bpxdi1 = coalesce(bpxdi1, bpxodi1),
    bpxdi2 = coalesce(bpxdi2, bpxodi2),
    bpxdi3 = coalesce(bpxdi3, bpxodi3),

    # -------------------------------------------------------------------------
    # RACE / ETHNICITY
    # RIDRETH3 has the Asian subgroup (2011+); RIDRETH1 used as fallback.
    # -------------------------------------------------------------------------
    race_eth_init = case_when(
      is.na(ridreth3) ~ ridreth1,
      .default        = ridreth3
    ),
    race_ethnicity = fct_relevel(
      factor(case_when(
        str_detect(race_eth_init, "Race - Inc|Race, Inc") ~
          "Other Race, including Multi-Racial",
        .default = race_eth_init
      )),
      "Non-Hispanic White"
    ),

    # -------------------------------------------------------------------------
    # EDUCATION (adults 20+; dmdeduc2 only; teens handled separately if needed)
    # -------------------------------------------------------------------------
    education = factor(
      case_when(
        dmdeduc2 %in% c(
          "Less than 9th Grade", "Less than 9th grade",
          "9-11th Grade (Includes 12th grade with no diploma)",
          "9-11th grade (Includes 12th grade with no diploma)"
        ) ~ "Less than high school",
        dmdeduc2 %in% c(
          "High School Grad/GED or Equivalent",
          "High school graduate/GED or equivalent"
        ) ~ "High school graduate (including GED)",
        dmdeduc2 %in% c(
          "Some College or AA degree", "Some college or AA degree"
        ) ~ "Some college or associate's degree",
        dmdeduc2 %in% c(
          "College Graduate or above", "College graduate or above"
        ) ~ "College graduate or above",
        dmdeduc2 %in% c("Don't Know", "Don't know", "Refused") ~ NA_character_,
        TRUE ~ NA_character_
      ),
      levels = c(
        "Less than high school",
        "High school graduate (including GED)",
        "Some college or associate's degree",
        "College graduate or above"
      )
    ),

    # -------------------------------------------------------------------------
    # INCOME — categorical
    # indhhin2 (2007+) and indhhinc (1999–2006) have overlapping but differently
    # labelled levels. Coalesced into income_raw then collapsed to four tiers.
    # -------------------------------------------------------------------------
    income_raw = dplyr::coalesce(
      as.character(indhhin2),
      as.character(indhhinc)
    ),
    income_cat = factor(
      case_when(
        income_raw %in% c(
          "Under $20,000",
          "$ 0 to $ 4,999", "$     0 to $ 4,999",
          "$ 5,000 to $ 9,999",
          "$10,000 to $14,999",
          "$15,000 to $19,999",
          "$ 0 to $4,999", "$ 5,000 to $9,999"
        ) ~ "Under $20,000",
        income_raw %in% c(
          "Over $20,000", "$20,000 and Over",
          "$20,000 to $24,999", "$25,000 to $34,999",
          "$35,000 to $44,999", "$45,000 to $54,999",
          "$55,000 to $64,999", "$65,000 to $74,999"
        ) ~ "$20,000 to $74,999",
        income_raw == "$75,000 to $99,999"          ~ "$75,000 to $99,999",
        income_raw %in% c(
          "$100,000 and over", "$100,000 and Over"
        ) ~ "$100,000 and over",
        income_raw %in% c("Refused", "Don't know", "Don't Know") ~ "Missing",
        is.na(income_raw) ~ "Missing"
      ),
      levels = c(
        "Under $20,000", "$20,000 to $74,999",
        "$75,000 to $99,999", "$100,000 and over", "Missing"
      )
    ),

    # PIR – poverty-income ratio (continuous; already in DEMO, just rename)
    # Higher = higher income relative to poverty line. Common cut: <1.3 = poor.
    pir = indfmpir,

    # -------------------------------------------------------------------------
    # MARITAL STATUS
    # -------------------------------------------------------------------------
    marital_status = factor(
      case_when(
        dmdmartl %in% c("Married", "Living with partner") ~
          "Married or living with partner",
        dmdmartl %in% c(
          "Never married", "Separated", "Divorced", "Widowed"
        ) ~ "Never married, separated, divorced, or widowed",
        dmdmartl %in% c("Refused", "Don't know", "Don't Know") ~ NA_character_,
        TRUE ~ NA_character_
      ),
      levels = c(
        "Married or living with partner",
        "Never married, separated, divorced, or widowed"
      )
    ),

    # -------------------------------------------------------------------------
    # NATIVITY / YEARS IN US
    # Variable names changed across cycles (dmdborn, dmdborn2, dmdborn4).
    # nhanesdata stores all cycles in the same column after bind_rows; the
    # string content is what varies. We detect US-born by string pattern.
    # -------------------------------------------------------------------------
    born_us = case_when(
      str_detect(
        coalesce(as.character(dmdborn4), as.character(dmdborn2)),
        regex("50 US States|United States|Born in US", ignore_case = TRUE)
      ) ~ TRUE,
      !is.na(coalesce(as.character(dmdborn4), as.character(dmdborn2))) ~ FALSE,
      TRUE ~ NA
    ),
    nativity = case_when(
      born_us == TRUE  & ridageyr < 10  ~ "US born, less than 10 yrs",
      born_us == TRUE  & ridageyr >= 10 ~ "US born, more than 10 yrs",
      born_us == FALSE & dmdyrsus %in% c(
        "Less than 1 year",
        "1 yr., less than 5 yrs.",
        "5 yrs., less than 10 yrs.",
        "1 year or more, but less than 5 years",
        "5 year or more, but less than 10 years"
      ) ~ "Born abroad, less than 10 years in US",
      born_us == FALSE & dmdyrsus %in% c(
        "10 yrs., less than 15 yrs.",
        "10 year or more, but less than 15 years",
        "15 yrs., less than 20 yrs.",
        "15 year or more, but less than 20 years",
        "20 yrs., less than 30 yrs.",
        "20 year or more, but less than 30 years",
        "30 yrs., less than 40 yrs.",
        "30 year or more, but less than 30 years",
        "40 yrs., less than 50 yrs.",
        "40 year or more, but less than 50 years",
        "50 years or more"
      ) ~ "Born abroad, more than 10 years in US",
      .default = NA_character_
    ),

    # -------------------------------------------------------------------------
    # HEALTH INSURANCE
    # -------------------------------------------------------------------------
    has_health_ins = factor(
      case_when(
        hiq011 == "Yes" ~ "Yes",
        hiq011 == "No"  ~ "No",
        TRUE            ~ NA_character_
      ),
      levels = c("Yes", "No")
    ),

    # -------------------------------------------------------------------------
    # SMOKING
    # -------------------------------------------------------------------------
    smq020 = factor(
      smq020,
      levels = c("Yes", "No", "Refused", "Don't know")
    ),
    smq040 = factor(
      case_when(
        smq040 %in% c("Not at all", "Not at all?")   ~ "No",
        smq040 %in% c("Some days, or", "Some days")  ~ "Some days",
        smq040 %in% c("Every day", "Every day,")     ~ "Every day",
        smq040 == "Refused"                          ~ "Refused",
        .default = NA_character_
      ),
      levels = c("No", "Some days", "Every day", "Refused")
    ),
    smoking_status = factor(
      case_when(
        smq020 == "No"                                             ~ "Never",
        smq020 == "Yes" & smq040 %in% c("Every day", "Some days") ~ "Current",
        smq020 == "Yes" & smq040 == "No"                          ~ "Former"
      ),
      levels = c("Never", "Current", "Former")
    ),

    # -------------------------------------------------------------------------
    # ALCOHOL USE
    # -------------------------------------------------------------------------
    alcohol_status = factor(
      case_when(
        alq110 %in% c("Don't know", "Refused") |
          alq120q >= 777 ~ "Not provided",
        alq110 == "No"                                        ~ "Never",
        alq110 == "Yes" & alq120q == 0                        ~ "Former",
        alq110 == "Yes" & between(alq120q, 1, 700)            ~ "Current",
        alq110 == "Yes" & (alq120q == 999 | is.na(alq120q))   ~ "Not provided",
        is.na(alq110) & !is.na(alq120u)                       ~ "Current",
        is.na(alq110) & alq120q == 0 ~
          "Does not currently drink, hx unknown",
        .default = alq110
      ),
      levels = c(
        "Never", "Does not currently drink, hx unknown",
        "Former", "Current", "Not provided"
      )
    ),
    alcohol_current = factor(
      case_when(
        alcohol_status == "Current" ~ "Drinks alcohol",
        alcohol_status %in%
          c("Does not currently drink, hx unknown", "Former", "Never") ~
          "Does not drink alcohol",
        TRUE ~ NA_character_
      ),
      levels = c("Does not drink alcohol", "Drinks alcohol")
    ),

    # -------------------------------------------------------------------------
    # PHYSICAL ACTIVITY  (MET-minutes/week)
    #
    # *** PAQ COVERAGE WARNING — NA BY DESIGN IN SIX CYCLES ***
    # The paq605/paq610/pad615 etc. variable series (used here) was introduced
    # in the 2007–2008 redesign. Cycles 1999–2006 used different PAQ variable
    # names that are not harmonized here. Additionally, these sub-questions
    # were removed in the 2017–2018 redesign and remain absent in 2021.
    # total_met_min is NA by design for:
    #   year == 1999, 2001, 2003, 2005  (pre-2007 PAQ variable names)
    #   year == 2017, 2021              (PAQ restructured / removed)
    # Valid MET-min data exists for 2007–2015 only (5 cycles).
    # This is NOT a join error. For PA data outside these cycles, consider
    # accelerometer-based data (paxday / paxhd tables).
    #
    # The "9999" values are "Don't know/refused" skip codes; imputed with the
    # median of valid responses for that component.
    # Cap at 16 hrs/day × 7 days × 8 MET = 53,760 MET-min/week (biologically
    # impossible values set to NA rather than silently truncated).
    # -------------------------------------------------------------------------
    vig_work_min_week = case_when(
      pad615 == 9999  ~ paq610 * median(pad615, na.rm = TRUE),
      paq605 == "No"  ~ 0,
      .default        = paq610 * pad615
    ),
    mod_work_min_week = case_when(
      pad630 == 9999  ~ paq625 * median(pad630, na.rm = TRUE),
      paq620 == "No"  ~ 0,
      .default        = paq625 * pad630
    ),
    transp_min_week = case_when(
      pad645 == 9999  ~ paq640 * median(pad645, na.rm = TRUE),
      paq635 == "No"  ~ 0,
      .default        = paq640 * pad645
    ),
    vig_rec_min_week = case_when(
      pad660 == 9999  ~ paq655 * median(pad660, na.rm = TRUE),
      paq650 == "No"  ~ 0,
      .default        = paq655 * pad660
    ),
    mod_rec_min_week = case_when(
      pad675 == 9999  ~ paq670 * median(pad675, na.rm = TRUE),
      paq665 == "No"  ~ 0,
      .default        = paq670 * pad675
    ),
    vig_met_min   = (vig_work_min_week + vig_rec_min_week) * 8.0,
    mod_met_min   = (mod_work_min_week + mod_rec_min_week + transp_min_week) * 4.0,
    total_met_min = vig_met_min + mod_met_min,
    total_met_min = if_else(total_met_min > 53760, NA_real_, total_met_min),
    pa_level = factor(
      case_when(
        total_met_min == 0                              ~ "Inactive",
        total_met_min > 0    & total_met_min < 600      ~ "Low",
        total_met_min >= 600 & total_met_min < 1200     ~ "Moderate",
        total_met_min >= 1200                           ~ "Vigorous",
        TRUE ~ NA_character_
      ),
      levels = c("Inactive", "Low", "Moderate", "Vigorous")
    ),
    phys_active = factor(
      case_when(
        is.na(total_met_min)  ~ NA_character_,
        total_met_min >= 600  ~ "Active",
        total_met_min <  600  ~ "Inactive"
      ),
      levels = c("Inactive", "Active")
    ),

    # =========================================================================
    # NEW VARIABLES (not in original create_base.R)
    # =========================================================================

    # -------------------------------------------------------------------------
    # BODY MASS INDEX
    # bmxbmi is already continuous from nhanesdata; derive categories.
    # Standard WHO / CDC adult cut-points. Meaningful only for adults (≥20 yrs).
    # -------------------------------------------------------------------------
    bmi = bmxbmi,
    bmi_cat = factor(
      case_when(
        ridageyr < 20            ~ NA_character_,
        is.na(bmxbmi)            ~ NA_character_,
        bmxbmi < 18.5            ~ "Underweight",
        bmxbmi < 25.0            ~ "Normal weight",
        bmxbmi < 30.0            ~ "Overweight",
        bmxbmi >= 30.0           ~ "Obese"
      ),
      levels = c("Underweight", "Normal weight", "Overweight", "Obese")
    ),

    # -------------------------------------------------------------------------
    # BLOOD PRESSURE (measured)
    # BPX protocol: 3 readings taken; standard epidemiologic practice is to
    # average readings 2 & 3 (exclude the first as acclimation). Falls back
    # to reading 1 if readings 2 & 3 are both NA.
    # bpxsy*/bpxdi* already coalesced with bpxo equivalents above.
    # DBP = 0 indicates measurement failure — set to NA.
    # -------------------------------------------------------------------------
    mean_sbp = rowMeans(cbind(bpxsy2, bpxsy3), na.rm = TRUE),
    mean_dbp = rowMeans(cbind(bpxdi2, bpxdi3), na.rm = TRUE),
    mean_sbp = if_else(is.nan(mean_sbp), bpxsy1, mean_sbp),
    mean_dbp = if_else(is.nan(mean_dbp), bpxdi1, mean_dbp),
    mean_dbp = if_else(mean_dbp == 0, NA_real_, mean_dbp),
    mean_sbp = if_else(mean_sbp == 0, NA_real_, mean_sbp),

    # -------------------------------------------------------------------------
    # HYPERTENSION
    # JNC-7 (≥140/90) and AHA 2017 (≥130/80) definitions both retained.
    # Self-report (bpq020) and BP-medication use (bpq050a) included.
    # -------------------------------------------------------------------------
    bp_meds = case_when(
      bpq050a == "Yes" ~ TRUE,
      bpq050a == "No"  ~ FALSE,
      TRUE             ~ NA
    ),
    htn_selfreport = case_when(
      bpq020 == "Yes" ~ TRUE,
      bpq020 == "No"  ~ FALSE,
      TRUE            ~ NA
    ),
    hypertension_jnc7 = case_when(
      is.na(mean_sbp) & is.na(htn_selfreport) & is.na(bp_meds) ~ NA,
      isTRUE(bp_meds)           ~ TRUE,
      isTRUE(htn_selfreport)    ~ TRUE,
      !is.na(mean_sbp) & (mean_sbp >= 140 | mean_dbp >= 90) ~ TRUE,
      !is.na(mean_sbp) & (mean_sbp < 140  & mean_dbp < 90)  ~ FALSE,
      .default = NA
    ),
    hypertension_aha = case_when(
      is.na(mean_sbp) & is.na(htn_selfreport) & is.na(bp_meds) ~ NA,
      isTRUE(bp_meds)           ~ TRUE,
      isTRUE(htn_selfreport)    ~ TRUE,
      !is.na(mean_sbp) & (mean_sbp >= 130 | mean_dbp >= 80) ~ TRUE,
      !is.na(mean_sbp) & (mean_sbp < 130  & mean_dbp < 80)  ~ FALSE,
      .default = NA
    ),
    hypertension = hypertension_jnc7,

    # -------------------------------------------------------------------------
    # DIABETES
    # diq010: doctor-diagnosed diabetes; diq050/diq070: on insulin or pills.
    # Composite: self-report OR on medication = TRUE.
    # -------------------------------------------------------------------------
    diabetes = case_when(
      diq010 == "Yes"                          ~ TRUE,
      diq050 == "Yes" | diq070 == "Yes"        ~ TRUE,
      diq010 == "Borderline"                   ~ NA,
      diq010 == "No"                           ~ FALSE,
      TRUE                                     ~ NA
    ),
    diabetes_borderline = case_when(
      diq010 == "Borderline"    ~ TRUE,
      diq010 %in% c("Yes","No") ~ FALSE,
      TRUE ~ NA
    ),

    # -------------------------------------------------------------------------
    # HYPERLIPIDEMIA / DYSLIPIDEMIA
    # (a) Self-report: bpq080 — doctor-diagnosed high cholesterol.
    # (b) Measured: total cholesterol ≥ 240 mg/dL (NCEP borderline-high cut).
    # Both retained; composite uses either source.
    # -------------------------------------------------------------------------
    highchol_selfreport = case_when(
      bpq080 == "Yes" ~ TRUE,
      bpq080 == "No"  ~ FALSE,
      TRUE            ~ NA
    ),
    highchol_measured = case_when(
      is.na(lbxtc) ~ NA,
      lbxtc >= 240 ~ TRUE,
      lbxtc <  240 ~ FALSE
    ),
    hyperlipidemia = case_when(
      isTRUE(highchol_selfreport) | isTRUE(highchol_measured) ~ TRUE,
      !is.na(highchol_selfreport) | !is.na(highchol_measured) ~ FALSE,
      TRUE ~ NA
    ),
    total_cholesterol = lbxtc,

    # -------------------------------------------------------------------------
    # OCQ SENTINEL CODE RECODE
    # ocq180 uses 77777 (refused) and 99999 (don't know) as skip codes.
    # These must be set to NA before analysis; they are not real hour values.
    # -------------------------------------------------------------------------
    ocq180 = if_else(ocq180 %in% c(77777L, 99999L), NA_real_, as.numeric(ocq180))

  )



#### 5. Select columns for the base_small object ####

base_small <- base |>
  select(
    # ----- Keys ---------------------------------------------------------------
    year, seqn,

    # ----- Survey design & weights -------------------------------------------
    sdmvpsu, sdmvstra,
    wtint2yr,    # interview weight  (use when all covariates from interview)
    wtmec2yr,    # exam/MEC weight   (use when any covariate from exam/lab)
                 # NOTE: 2021 stores a proportionally adjusted 2-yr-equivalent
                 # weight — confirm with Kyle before pooled analyses.

    # ----- Core demographics --------------------------------------------------
    ridageyr,    # age in years (continuous)
    riagendr,    # sex (Male / Female)
    race_ethnicity,
    ridpreg,     # pregnancy status at MEC exam (females 8–59; NA otherwise)
                 # nhanesdata name for CDC's RIDEXPREG.
                 # 1=positive lab test, 2=self-reported, 3=cannot ascertain
                 # Use for exclusion criteria in study-specific scripts.

    # ----- Socioeconomic & household ------------------------------------------
    education,
    income_cat,
    pir,         # poverty-income ratio (continuous)
    marital_status,

    # ----- Nativity -----------------------------------------------------------
    nativity,

    # ----- Health insurance ---------------------------------------------------
    has_health_ins,

    # ----- Health behaviours --------------------------------------------------
    smoking_status,
    alcohol_status, alcohol_current,
    total_met_min, pa_level, phys_active,
    # NOTE: total_met_min is NA by design for year==1999, 2001, 2003, 2005,
    #       2017, and 2021. Valid MET-min data exists for 2007–2015 only
    #       (5 of 11 cycles).

    # ----- Body composition ---------------------------------------------------
    bmi,         # continuous (kg/m²)
    bmi_cat,     # 4-level: Underweight / Normal / Overweight / Obese

    # ----- Cardiovascular / cardiometabolic -----------------------------------
    mean_sbp,           # mean systolic BP (mmHg, avg readings 2 & 3)
    mean_dbp,           # mean diastolic BP (mmHg, avg readings 2 & 3)
    bp_meds,            # currently on BP medication (logical)
    htn_selfreport,     # ever told high BP (logical)
    hypertension,       # composite JNC-7 flag (primary)
    hypertension_jnc7,  # SBP≥140 or DBP≥90 or meds or self-report
    hypertension_aha,   # SBP≥130 or DBP≥80 or meds or self-report

    # ----- Diabetes -----------------------------------------------------------
    diabetes,            # composite: self-report OR on meds (logical)
    diabetes_borderline,

    # ----- Lipids -------------------------------------------------------------
    total_cholesterol,   # lbxtc (mg/dL, continuous); available 2005+ only
    highchol_selfreport, # ever told high cholesterol (logical)
    highchol_measured,   # TC ≥ 240 mg/dL (logical)
    hyperlipidemia,      # composite (logical)

    # ----- Occupation (OCQ) ---------------------------------------------------
    # ocq180:  hours/week at current/most recent job (continuous).
    #          NA by design for participants not working in past 12 months.
    # ocq210:  worked more than one job in past week (Yes/No).
    # ocq260:  work arrangement: employee, self-employed, etc.
    # ocq670:  work schedule (day/evening/night/rotating). Present in nhanesdata
    #          for 2017 ONLY (confirmed by QC); NA for all other cycles.
    #          Variable exists in the OCQ table but 2013/2015/2021 coverage is
    #          absent — likely a nhanesdata ingestion gap, not a CDC omission.
    ocq180, ocq210, ocq260, ocq670,

    # ----- Drug use / cannabis (DUQ) -----------------------------------------
    # NOT available for 1999, 2001, or 2003 (NA by design).
    #   - 1999: DUQ not collected that cycle.
    #   - 2001 (DUQ_B) and 2003 (DUQ_C): collected by NCHS but classified as
    #     restricted-access sensitive data; not publicly downloadable and
    #     therefore absent from nhanesdata. Public data begins with 2005.
    # Age eligibility varies by cycle (participants outside range have NA):
    #   20–59 (2005–2006), 18–69 (2007–2010), 18–59 (2011–2021).
    # duq200:  ever used marijuana or hashish (Yes/No) — most stable variable.
    # duq210:  age first used marijuana (years).
    # duq220q: quantity component for times used marijuana in past 12 months.
    # duq220u: unit component for times used marijuana in past 12 months.
    #          Derive duq220 (combined frequency) from duq220q + duq220u downstream.
    # duq230:  avg days/month used marijuana in past 12 months.
    #          Response scale shifted in 2007–2008 — use cautiously across cycles.
    duq200, duq210, duq220q, duq220u, duq230,

    # ----- Mortality (NCHS Linked Mortality File) -----------------------------
    # LMF covers 1999–2018 survey participants; follow-up through Dec 31, 2019.
    # ALL 2021 participants have NA for these variables (not yet in LMF).
    #
    # eligstat:    1 = eligible for mortality linkage (age 18+)
    #              2 = not eligible (age <18); filter to eligstat==1 in
    #                  study-specific scripts before building survival outcomes.
    # mortstat:    0 = assumed alive at Dec 31 2019
    #              1 = presumed dead (death certificate found)
    #              NA = not eligible (eligstat==2) or not yet linked (2021)
    # ucod_leading: leading underlying cause of death integer code.
    #              1=heart disease, 2=cancer, 3=COPD, 4=accidents, 5=stroke,
    #              6=Alzheimer's, 7=diabetes, 8=flu/pneumonia, 9=nephritis,
    #              10=all other. NA if alive or ineligible.
    #              Derive all-cause / CVD / cancer outcomes downstream.
    # diab_mort:   diabetes as contributing cause on death certificate (0/1).
    #              DISTINCT from the comorbidity variable `diabetes`.
    # htn_mort:    hypertension as contributing cause on death certificate (0/1).
    #              DISTINCT from the comorbidity variable `hypertension`.
    # permth_int:  person-months of follow-up from interview date.
    # permth_exm:  person-months of follow-up from MEC exam date.
    #              Use permth_int when the primary exposure comes from interview
    #              data (e.g., OCQ work hours); permth_exm for exam-based
    #              exposures. Both retained for analyst flexibility.
    eligstat, mortstat, ucod_leading,
    diab_mort, htn_mort,
    permth_int, permth_exm
  )



#### 6. Data quality checks ####

message("\n--- Data Quality Report ---\n")

# 6a. Row counts by year
# Expect ~9,000–11,000 per 2-year cycle; ~10,000–12,000 for 2021 (3-year).
message("Rows by cycle:")
print(base_small |> count(year))

# 6b. Missing rates for every selected column
message("\nMissing rates (%) by column:")
miss_rates <- base_small |>
  summarise(across(everything(), ~ round(mean(is.na(.)) * 100, 1))) |>
  tidyr::pivot_longer(everything(), names_to = "variable", values_to = "pct_missing") |>
  arrange(desc(pct_missing))
print(miss_rates, n = Inf)

# 6c. Numeric variable ranges — flag impossible values
message("\nNumeric variable ranges:")
base_small |>
  summarise(
    age_min    = min(ridageyr,          na.rm = TRUE),
    age_max    = max(ridageyr,          na.rm = TRUE),
    bmi_min    = min(bmi,               na.rm = TRUE),
    bmi_max    = max(bmi,               na.rm = TRUE),
    sbp_min    = min(mean_sbp,          na.rm = TRUE),
    sbp_max    = max(mean_sbp,          na.rm = TRUE),
    dbp_min    = min(mean_dbp,          na.rm = TRUE),
    dbp_max    = max(mean_dbp,          na.rm = TRUE),
    tc_min     = min(total_cholesterol, na.rm = TRUE),
    tc_max     = max(total_cholesterol, na.rm = TRUE),
    met_min    = min(total_met_min,     na.rm = TRUE),
    met_max    = max(total_met_min,     na.rm = TRUE),
    pir_min    = min(pir,               na.rm = TRUE),
    pir_max    = max(pir,               na.rm = TRUE),
    hrs_wk_min = min(ocq180,            na.rm = TRUE),
    hrs_wk_max = max(ocq180,            na.rm = TRUE),
    permth_min = min(permth_exm,        na.rm = TRUE),
    permth_max = max(permth_exm,        na.rm = TRUE)
  ) |>
  tidyr::pivot_longer(everything(), names_to = "stat", values_to = "value") |>
  print()

# 6d. Factor level distributions
message("\nrace_ethnicity levels:")
print(base_small |> count(race_ethnicity, sort = TRUE))

message("\neducation levels:")
print(base_small |> count(education, sort = TRUE))

message("\nbmi_cat levels:")
print(base_small |> count(bmi_cat, sort = TRUE))

message("\nhypertension distribution by year:")
print(base_small |> count(hypertension, year) |>
  tidyr::pivot_wider(names_from = year, values_from = n))

message("\ndiabetes distribution by year:")
print(base_small |> count(diabetes, year) |>
  tidyr::pivot_wider(names_from = year, values_from = n))

# 6e. PA missingness by year
# Expect 100% missing for year==1999, 2001, 2003, 2005 (pre-2007 PAQ names),
# year==2017 and year==2021 (PAQ restructured). Valid data: 2007–2015 only.
message("\nPA (total_met_min) missing rate by year:")
print(
  base_small |>
    group_by(year) |>
    summarise(pct_pa_missing = round(mean(is.na(total_met_min)) * 100, 1), n = n())
)

# 6f. Mortality coverage by year
# Expect non-NA mortstat for 1999–2017 eligible adults; 0% for year==2021.
message("\nMortality coverage by year (% with non-NA mortstat):")
print(
  base_small |>
    group_by(year) |>
    summarise(pct_linked = round(mean(!is.na(mortstat)) * 100, 1), n = n())
)

# 6g. DUQ coverage by year
# Expect 0% present for year==1999; age-restriction pattern visible in others.
message("\nDUQ (duq200) non-missing rate by year:")
print(
  base_small |>
    group_by(year) |>
    summarise(pct_duq_present = round(mean(!is.na(duq200)) * 100, 1), n = n())
)

# 6h. OCQ work schedule (ocq670) coverage by year
# Expect 0% present for years 1999–2011 (variable collected 2013+ only).
message("\nOCQ work schedule (ocq670) non-missing rate by year:")
print(
  base_small |>
    group_by(year) |>
    summarise(pct_ocq670_present = round(mean(!is.na(ocq670)) * 100, 1), n = n())
)

# 6i. Survey weight sanity checks
stopifnot(
  "Negative wtmec2yr found" = all(base_small$wtmec2yr >= 0, na.rm = TRUE),
  "Negative wtint2yr found" = all(base_small$wtint2yr >= 0, na.rm = TRUE)
)

# 6j. PIR range check
if (any(base_small$pir > 10, na.rm = TRUE)) {
  warning(sum(base_small$pir > 10, na.rm = TRUE),
          " rows have PIR > 10 — check for coding errors.")
}

# 6k. OCQ hours check (>99 hrs/week; sentinel codes 77777/99999 already NA).
# Remaining values >99 are expected to be real extreme-hour workers.
# Note: some cycles used 100 as a ceiling code ("100 or more") — interpret
# the value 100 with caution in continuous models.
if (any(base_small$ocq180 > 99, na.rm = TRUE)) {
  message(sum(base_small$ocq180 > 99, na.rm = TRUE),
          " rows have ocq180 > 99 hrs/week (max = ",
          max(base_small$ocq180, na.rm = TRUE),
          "). Sentinel codes already removed — these are likely real values.")
}

message("\nAll QC checks passed.")



#### 7. Upload to Cloudflare R2 ####

nhanesdata:::nhanes_r2_upload(
  x      = base_small,
  name   = "base_1999_2021",
  bucket = "nhanes-data"
)
