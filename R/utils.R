#' Internal Utility Functions
#'
#' @description This file contains internal helper functions used across the
#'   nhanesdata package. These functions are not exported and are meant for
#'   internal package use only.
#'
#' @keywords internal
#' @name utils
NULL

#' @importFrom utils globalVariables
utils::globalVariables(c("year", "seqn", "Begin.Year", "Variable.Name"))

#----------------------------------------------------------------------------------------
#' Internal: Get Survey Cycle Start Year from Table Suffix
#'
#' Maps NHANES table suffix letters to survey cycle start years.
#' This is an internal helper function used by \code{get_url()} and
#' other functions that need to interpret table suffixes.
#'
#' @param suffix Character. Single letter suffix (e.g., 'J', 'B') or
#'   empty string for the 1999-2000 cycle.
#'
#' @return Integer. Start year of survey cycle (e.g., 2017 for 'J'),
#'   or NULL if suffix is not recognized.
#'
#' @details
#' NHANES uses letter suffixes to denote survey cycles:
#' \itemize{
#'   \item No suffix or 'A' = 1999-2000
#'   \item 'B' = 2001-2002, 'C' = 2003-2004, etc.
#'   \item 'K' is skipped (2019-2020 cycle had data collection issues)
#'   \item 'L' = 2021-2023 (resumed cycle)
#' }
#'
#' Some special datasets use 'S' or 'U' suffixes for 2017-2018 data.
#'
#' @keywords internal
#' @noRd
.get_year_from_suffix <- function(suffix) {
  # Handle empty suffix (no letter = 1999-2000 cycle)
  if (suffix == "") {
    return(1999L)
  }

  # Standard NHANES suffix to year mapping
  mapping <- c(
    "A" = 1999L, # Edge case: some datasets use _A for 1999-2000
    "B" = 2001L,
    "C" = 2003L,
    "D" = 2005L,
    "E" = 2007L,
    "F" = 2009L,
    "G" = 2011L,
    "H" = 2013L,
    "I" = 2015L,
    "J" = 2017L,
    "L" = 2021L, # Note: K is skipped (2019-2020 cycle issues)
    "S" = 2017L, # Special datasets from 2017-2018
    "U" = 2017L # Special datasets from 2017-2018
  )

  year <- mapping[suffix]
  if (is.na(year)) {
    return(NULL)
  }
  unname(year)
}
