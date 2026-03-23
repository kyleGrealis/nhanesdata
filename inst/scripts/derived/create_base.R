################################################################################
# Title: Base NHANES Dataset Creation (2009-2018)
# Date: 2026-02-22
################################################################################



#### Purpose ####

# This script builds a base dataset for NHANES cycles 2009–2018. It downloads
#   the DEMO (demographics), HIQ (insurance), SMQ (smoking), ALQ (alcohol), and
#   PAQ (physical activity) tables, filters to the selected cycles, and
#   left-joins the tables by year and seqn to create one row per participant per
#   cycle.

# We create analysis-ready versions of key variables: a cleaned race/ethnicity
#   variable, collapsed education, income, and marital status variables with
#   nonresponse set to NA (or “Missing” for income), a nativity/years-in-US
#   variable, a binary insurance variable, smoking status (never, current, or
#   former), alcohol use status (never/former/current/not provided) plus a
#   binary current drinking indicator, a continuous total MET-minutes variable,
#   and activity categories (4-level and binary).


#### Setup ####

# Load packages
library(dplyr)
library(stringr)
library(forcats)
library(nhanesdata)
library(janitor)

# Cycle start years to include
years <- c(2009, 2011, 2013, 2015, 2017)

# Pull NHANES tables
demo <- nhanesdata::read_nhanes("demo") |> filter(year %in% years)
hiq  <- nhanesdata::read_nhanes("hiq")  |> filter(year %in% years)
smq  <- nhanesdata::read_nhanes("smq")  |> filter(year %in% years)
alq  <- nhanesdata::read_nhanes("alq")  |> filter(year %in% years)
paq  <- nhanesdata::read_nhanes("paq")  |> filter(year %in% years)



#### Cleaning ####

# Join into base dataset
base <- demo |>
  left_join(hiq, by = c("year", "seqn")) |>
  left_join(smq, by = c("year", "seqn")) |>
  left_join(alq, by = c("year", "seqn")) |>
  left_join(paq, by = c("year", "seqn"))
# nrow(base)   # 49,693

base <- base |>
  # clean names to all lowercase
  janitor::clean_names() |>
  mutate(

    # Refer to this page on why using default value from RIDRETH3.
    # https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/DEMO_L.htm
    # RIDRETH3 has values for Asian, but has missingness where RIDRETH1 does not
    race_eth_init = case_when(
      is.na(ridreth3) ~ ridreth1,
      .default = ridreth3
    ),
    # Further clean the ethnicity variable
    race_ethnicity = fct_relevel(
      factor(case_when(
        # just a minor stylistic tweak to replace the dash for a comma
        str_detect(race_eth_init, 'Race - Inc')
        ~ 'Other Race, including Multi-Racial',
        .default = race_eth_init
        )
      ),
      'Non-Hispanic White'  # Reference level is NH White
    ),

    education = factor(
      case_when(
        dmdeduc2 %in% c(
          'Less than 9th Grade',
          'Less than 9th grade',
          '9-11th Grade (Includes 12th grade with no diploma)',
          '9-11th grade (Includes 12th grade with no diploma)'
        ) ~ 'Less than high school',
        dmdeduc2 %in% c(
          'High School Grad/GED or Equivalent',
          'High school graduate/GED or equivalent'
        ) ~ 'High school graduate (including GED)',
        dmdeduc2 %in% c(
          'Some College or AA degree',
          'Some college or AA degree'
        ) ~ 'Some college or associate\'s degree',
        dmdeduc2 %in% c(
          'College Graduate or above',
          'College graduate or above'
        ) ~ 'College graduate or above',
        dmdeduc2 %in% c('Don\'t Know', 'Don\'t know', 'Refused') ~ NA_character_,
        TRUE ~ NA_character_   # All "Don't know/Refused" or other set to NA
      ),
      levels = c(
        'Less than high school',
        'High school graduate (including GED)',
        'Some college or associate\'s degree',
        'College graduate or above'
      )
    ),

    # Income
    income = factor(
      case_when(
        indhhin2 %in% c(
          'Under $20,000',
          '$ 0 to $ 4,999',
          '$     0 to $ 4,999',
          '$ 5,000 to $ 9,999',
          '$10,000 to $14,999',
          '$15,000 to $19,999'
        ) ~ 'Under $20,000',
        indhhin2 %in% c(
          'Over $20,000',
          '$20,000 and Over',
          '$20,000 to $24,999',
          '$25,000 to $34,999',
          '$35,000 to $44,999',
          '$45,000 to $54,999',
          '$55,000 to $64,999',
          '$65,000 to $74,999'
        ) ~ '$20,000 to $74,999',
        indhhin2 == '$75,000 to $99,999' ~ '$75,000 to $99,999',
        indhhin2 %in%
          c('$100,000 and over', '$100,000 and Over')  ~ '$100,000 and over',
        indhhin2 %in% c('Refused', 'Don\'t know') ~ 'Missing',
        is.na(indhhin2) ~ 'Missing'
      ),
      levels = c(
        'Under $20,000',
        '$20,000 to $74,999',
        '$75,000 to $99,999',
        '$100,000 and over',
        'Missing'
      )
    ),

    marital_status = case_when(
      dmdmartl %in% c('Married', 'Living with partner') ~
        'Married or living with partner',
      dmdmartl %in% c(
        'Never married', 'Separated', 'Divorced', 'Widowed'
      ) ~ 'Never married, separated, divorced, or widowed',
      dmdmartl %in% c('Refused', 'Don\'t know', 'Don\'t Know') ~ NA_character_,
      TRUE ~ NA_character_   # All "Don't know/Refused" or other set to NA
    ),
    marital_status = factor(
      marital_status,
      levels = c(
        'Married or living with partner',
        'Never married, separated, divorced, or widowed'
      )
    ),

    # Years in US
    nativity = case_when(
      dmdborn2 == 'Born in 50 US States or Washington, DC' &
        ridageyr < 10 ~ 'US born, less than 10 yrs',
      dmdborn2 == 'Born in 50 US States or Washington, DC' &
        ridageyr >= 10 ~ 'US born, more than 10 yrs',
      dmdborn2 != 'Born in 50 US States or Washington, DC' &
        dmdyrsus %in% c(
          'Less than 1 year',
          '1 yr.,
          less than 5 yrs.',
          '5 yrs., less than 10 yrs.',
          '1 year or more, but less than 5 years',
          '5 year or more, but less than 10 years'
        ) ~ 'Born abroad, less than 10 years in US',
      dmdborn2 != 'Born in 50 US States or Washington, DC' &
        dmdyrsus %in% c(
          '5 yrs., less than 10 yrs.',
          '5 year or more, but less than 10 years ',
          '10 yrs., less than 15 yrs.',
          '10 year or more, but less than 15 years',
          '15 yrs., less than 20 yrs.',
          '15 year or more, but less than 20 years',
          '20 yrs., less than 30 yrs.',
          '20 year or more, but less than 30 years',
          '30 yrs., less than 40 yrs.',
          '30 year or more, but less than 40 years',
          '40 yrs., less than 50 yrs.',
          '40 year or more, but less than 50 years',
          '50 years or more'
        ) ~ 'Born abroad, more than 10 years in US',
      .default = NA_character_
    ),

    # Health insurance
    has_health_ins = case_when(
      hiq011 == "Yes" ~ "Yes",
      hiq011 == "No"  ~ "No",
      TRUE ~ NA_character_          # All else becomes NA
    ),
    has_health_ins = factor(
      has_health_ins,
      levels = c("Yes", "No")
    ),

    # smoked at least 100 cigarettes in life
    smq020 = factor(
      smq020,
      levels = c(
        'Yes',
        'No',
        'Refused',
        'Don\'t know'
      )
    ),
    # do you now smoke cigarettes
    smq040 = factor(
      case_when(
        smq040 %in% c('Not at all', 'Not at all?') ~ 'No',
        smq040 %in% c('Some days, or', 'Some days') ~ 'Some days',
        smq040 %in% c('Every day', 'Every day,') ~ 'Every day',
        smq040 %in% c('Refused') ~ 'Refused',
        .default = NA_character_
      ),
      levels = c('No', 'Some days', 'Every day', 'Refused')
    ),
    # smoking status
    smoking_status = factor(
      case_when(
        smq020 == 'No' ~ 'Never',
        smq020 == 'Yes' & smq040 %in% c('Every day', 'Some days') ~ 'Current',
        smq020 == 'Yes' & smq040 == 'No' ~ 'Former'
      ),
      levels = c('Never', 'Current', 'Former')
    ),

    # Alcohol use
    alcohol_status = factor(
      case_when(
        alq110 %in% c('Don\'t know', 'Refused') |
          alq120q >= 777 ~ 'Not provided',
        alq110 == 'No' ~ 'Never',
        alq110 == 'Yes' & alq120q == 0 ~ 'Former',
        # using between() here to ensure value does not include escape codes
        # for refused or don't know:
        alq110 == 'Yes' & between(alq120q, 1, 700) ~ 'Current',
        alq110 == 'Yes' & (alq120q == 999 | is.na(alq120q)) ~ 'Not provided',
        # is.na(alq110) but reported values for alq120q & alq120u meaning they
        #   currently drink
        is.na(alq110) & !is.na(alq120u) ~ 'Current',
        # is.na(alq110) = no prior history, but report not currently drinking
        is.na(alq110) & alq120q == 0 ~ 'Does not currently drink, hx unknown',
        .default = alq110
      ),
      levels = c(
        'Never', 'Does not currently drink, hx unknown',
        'Former', 'Current', 'Not provided'
      )
    ),
    # Alternative binary alcohol use variable
    alcohol_current = factor(
      case_when(
        alcohol_status == "Current" ~ "Drinks alcohol",
        alcohol_status %in%
          c("Does not currently drink, hx unknown", "Former", "Never")
        ~ "Does not drink alcohol",
        TRUE ~ NA_character_   #  all else becomes NA
      ),
      levels = c("Does not drink alcohol", "Drinks alcohol")
    ),

    # Physical activity variables
    # We chose to impute the median when responses were 9999
    vig_work_min_week = case_when(
      pad615 == 9999 ~ paq610 * median(pad615, na.rm = TRUE),
      paq605 == 'No' ~ 0,
      .default = paq610 * pad615
    ),
    mod_work_min_week = case_when(
      pad630 == 9999 ~ paq625 * median(pad630, na.rm = TRUE),
      paq620 == 'No' ~ 0,
      .default = paq625 * pad630
    ),
    transp_min_week = case_when(
      pad645 == 9999 ~ paq640 * median(pad645, na.rm = TRUE),
      paq635 == 'No' ~ 0,
      .default = paq640 * pad645
    ),
    vig_rec_min_week = case_when(
      pad660 == 9999 ~ paq655 * median(pad660, na.rm = TRUE),
      paq650 == 'No' ~ 0,
      .default = paq655 * pad660
    ),
    mod_rec_min_week = case_when(
      pad675 == 9999 ~ paq670 * median(pad675, na.rm = TRUE),
      paq665 == 'No' ~ 0,
      .default = paq670 * pad675
    ),

    # Convert METS-minutes
    vig_met_min   = (vig_work_min_week + vig_rec_min_week) * 8.0,
    mod_met_min   = (
      mod_work_min_week +
        mod_rec_min_week +
        transp_min_week
      ) * 4.0,
    total_met_min = vig_met_min + mod_met_min,

    # 4-level Physical Activity category using MET-min/week thresholds
    pa_level = factor(
      case_when(
        total_met_min == 0 ~ "Inactive",
        total_met_min > 0 & total_met_min < 600 ~ "Low",
        total_met_min >= 600 & total_met_min < 1200 ~ "Moderate",
        total_met_min >= 1200 ~ "Vigorous",
        TRUE ~ NA_character_
      ),
      levels = c('Inactive', 'Low', 'Moderate', 'Vigorous')
    ),
    # Binary Physical Activity category using CDC's minimum 600 MET-min/week
    phys_active = case_when(
      is.na(total_met_min)   ~ NA_character_,
      total_met_min >= 600   ~ "Active",
      total_met_min < 600    ~ "Inactive"
    ),
    phys_active = factor(
      phys_active,
      levels = c("Inactive", "Active")
    )
  )



#### Select columns to keep ####
base_small <- base |>
  select(
    # Keys
    year, seqn,
    # Survey design and weights
    sdmvpsu, sdmvstra, wtint2yr, wtmec2yr,
    # Core demographics
    ridageyr, riagendr, race_ethnicity,
    # Socioeconomic and household
    education, income, marital_status,
    # Nativity - time in US
    nativity,
    # Insurance
    has_health_ins,
    # Smoking
    smoking_status,
    # Alcohol
    alcohol_status, alcohol_current,
    # Physical activity
    total_met_min, pa_level, phys_active
  )



#### Save ####
nhanesdata:::nhanes_r2_upload(
  x = base_small,
  name = "base_2009_2018",
  bucket = "nhanes-data"
)


