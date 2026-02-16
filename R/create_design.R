#' Calculate survey design weight within a NHANES dataset
#' 
#' @description
#' Input an NHANES dataset and apply the proper weight calculation. There are 3 
#' categories of weights:
#' \enumerate{
#'   \item Interview weight
#'   \item Mobile Exam Center (MEC) weight
#'   \item Fasting weight
#' }
#' The probability of being sampled for each type of NHANES category decreases from
#' interview to fasting samples. Therefore, when selecting the proper weight, the
#' practitioner should use the weight with the lowest probability when combining variables
#' across categories. For example, when performing an analysis using demographics 
#' (interview), diabetes information (interview), and DEXA scanning (MEC), the 
#' associated MEC weight is the proper weight variable to use.
#' 
#' It is also important to select the proper year grouping for the cycle. NHANES cycles
#' for 1999 and 2001 use 4-year sample weights, while all subsequent cycles use 2-year 
#' sample weights. This type of combination requires careful attention to:
#' \enumerate{
#'   \item The variables used, to determine weight category (interview, MEC, fasting).
#'   \item The cycles (years) used, to select proper year grouping variable.
#' }
#' 
#' This function will allow the user to input a dataset, select analysis start & end
#' years, and specify the type of weight category. The resulting survey design will
#' calculate the proper weight and apply that when creating the design object.
#' 
#' NOTE: It is \strong{not} required to specify variables for this function and it is
#' \strong{highly recommended} to perform preprocessing of variables \emph{before}
#' creating a complex design object.
#' 
#' See also \code{\link[srvyr]{as_survey_design}}
#' 
#' @details
#' \strong{Weight Calculation for Combined Cycles}
#' 
#' NHANES provides 4-year weights for the 1999-2000 and 2001-2002 cycles, while all
#' subsequent cycles provide only 2-year weights. When combining multiple cycles:
#' 
#' - If 1999 or 2001 cycles are included: Use the 4-year weight variable multiplied by
#'   \code{2/n} where \code{n} is the total number of cycles. The numerator is 2 because
#'   the 4-year weight represents two 2-year cycles.
#' - For cycles 2003 and beyond: Use the 2-year weight variable multiplied by \code{1/n}.
#' - The denominator \code{n} is always the total number of cycles in the analysis.
#' 
#' Example: Combining 4 cycles (1999, 2001, 2003, 2005):
#' \itemize{
#'   \item 1999 & 2001: \code{wtmec4yr * 2/4}
#'   \item 2003 & 2005: \code{wtmec2yr * 1/4}
#' }
#' 
#' Fasting weights (\code{wtsaf2yr}) are used with \code{1/n} multiplication. 
#' 
#' NOTE: 4-year fasting weights (\code{wtsaf4yr}) exist in NHANES laboratory files
#' for 1999-2002 but are not currently supported by this function.
#' 
#' @details
#' \strong{Fasting Subsample Weights}
#' 
#' For fasting subsample analyses combining 1999-2002 cycles, the 4-year fasting
#' weight (WTSAF4YR) exists in laboratory files (e.g., LAB10AM, LAB13AM) but is
#' typically NOT in demographic files obtained via nhanesA. If your dataset includes
#' merged laboratory fasting data from 1999-2002, ensure WTSAF4YR is present.
#' Otherwise, this function assumes only 2-year fasting weights (WTSAF2YR) are available.
#' 
#' @param dsn Tibble or data-frame.
#' @param start_yr Numeric. Lower bound for year filtering (inclusive).
#'   Must be an odd year representing a valid NHANES cycle start: 1999, 2001,
#'   2003, ..., 2019, 2021. For example, use 2007 for the 2007-2008 cycle.
#'   Data will be filtered to include years between start_yr and end_yr.
#' @param end_yr Numeric. Upper bound for year filtering (inclusive).
#'   Must be an odd year >= start_yr. Weight calculations are based on the
#'   number of cycles actually present in the filtered data, so it is valid
#'   to have gaps (e.g., start_yr=1999, end_yr=2017 with 2007-2010 missing).
#' @param wt_type Character. Category of weight to be used. Use the weight category with
#' the lowest probability of selection, but only if at least one variable from that
#' category is to be used. Accepts full names (\code{"interview"}, \code{"mec"},
#' \code{"fasting"}) or abbreviations (\code{"int"}, \code{"mec"}, \code{"fast"}).
#'
#' @return A survey design object of class \code{tbl_svy} (from srvyr package)
#'   containing the original data with calculated design weights and survey
#'   design metadata (PSUs, strata). Participants with zero or NA weights are
#'   retained in the design object but will be automatically excluded from
#'   most survey analyses.
#' 
#' @examples
#' \dontrun{
#' # Create a design object from interview-only variables
#' int_design <- create_design(nhanes_example, start_yr = 1999, end_yr = 2011, wt_type = "interview")
#' 
#' # Create a design object using interview & MEC variables
#' mec_design <- create_design(nhanes, start_yr = min(nhanes$year), end_yr = max(nhanes$year), wt_type = "mec")
#' }

create_design <- function(
  dsn, start_yr, end_yr,
  wt_type = c('interview', 'mec', 'fasting')
) {


  # Valid NHANES cycle start years (odd years representing 2-year cycles)
  valid_cycles <- seq(1999, 2021, by = 2)

  # Validate years arguments
  if (!is.numeric(start_yr) || !is.numeric(end_yr)) {
    stop("Args 'start_yr' and 'end_yr' must be numeric.")
  }

  if (!start_yr %in% valid_cycles) {
    stop(
      sprintf(
        "start_yr must be a valid NHANES cycle start year (odd year): %s",
        paste(valid_cycles, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (!end_yr %in% valid_cycles) {
    stop(
      sprintf(
        "end_yr must be a valid NHANES cycle start year (odd year): %s",
        paste(valid_cycles, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (end_yr < start_yr) {
    stop("end_yr must be >= start_yr", call. = FALSE)
  }

  # Validate weight type argument
  tryCatch(
    wt_type <- match.arg(wt_type),
    error = function(e) {
      stop(
        'Invalid weight type. Must be one of: "interview", "mec", or "fasting".',
        call. = FALSE
      )
    }
  )

  # Validate required columns exist
  if (!'year' %in% names(dsn)) {
    stop("Dataset must contain a 'year' column.", call. = FALSE)
  }

  # Filter based on years given
  import <- dsn |> filter(between(year, start_yr, end_yr))

  if (nrow(import) == 0) {
    stop(
      sprintf("No data found for years %d-%d", start_yr, end_yr),
      call. = FALSE
    )
  }

  # Count cycles PRESENT in data (CDC formula: n = number of cycles combined)
  cycles <- unique(import$year)

  # Validate that all years in data are valid NHANES cycle start years
  invalid_cycles <- setdiff(cycles, valid_cycles)
  if (length(invalid_cycles) > 0) {
    stop(
      sprintf(
        "Data contains invalid NHANES cycle years: %s. Must be odd years 1999-2021.",
        paste(invalid_cycles, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  # Validate required variables are available
  required_vars <- c('sdmvpsu', 'sdmvstra')
  needs_4yr <- any(import$year %in% c(1999, 2001))

  weight_vars <- switch(
    wt_type,
    'interview' = if (needs_4yr) c('wtint2yr', 'wtint4yr') else 'wtint2yr',
    'mec' = if (needs_4yr) c('wtmec2yr', 'wtmec4yr') else 'wtmec2yr',
    'fasting' = 'wtsaf2yr'
  )

  missing_vars <- setdiff(c(required_vars, weight_vars), names(import))

  if (length(missing_vars) > 0) {
    stop(
      sprintf('Missing required variables: %s', paste(missing_vars, collapse = ', ')),
      call. = FALSE
    )
  }

  # Create the survey dataset with new calculated weight variable
  survey_dat <- switch(
    wt_type,
    'interview' = import |> 
      mutate(
        design_weight = case_when(
          year %in% c(1999, 2001) ~ wtint4yr * 2/length(cycles),  # MUST use 4-yr weight
          .default = wtint2yr * 1/length(cycles)   # no 4-yr weight for these cycles
        )
      ),
    'mec' = import |> 
      mutate(
        design_weight = case_when(
          year %in% c(1999, 2001) ~ wtmec4yr * 2/length(cycles),  # MUST use 4-yr weight 
          .default = wtmec2yr * 1/length(cycles)   # no 4-yr weight for these cycles
        )
      ),
    'fasting' = import |> 
      mutate(
        design_weight = wtsaf2yr * 1/length(cycles)   # no 4-yr weight for this type
      )
  )

  zero_weights <- survey_dat |> filter(design_weight == 0 | is.na(design_weight))

  if (nrow(zero_weights) > 0) {
    message(sprintf(
      "Note: %d participants have zero/NA %s weights and will be retained in the design object.\n",
      nrow(zero_weights), wt_type
    ))
    message(
      "These participants were not in the subsample for this weight category and will be\n",
      "automatically excluded from analyses by the {survey} package."
    )
    
    # Optional: let user decide
    # survey_dat <- survey_dat |> filter(design_weight > 0, !is.na(design_weight))
  }

  # Set lonely PSU handling for variance estimation
  # "adjust" uses average of other strata with same number of PSUs
  options(survey.lonely.psu = "adjust")

  # Create the appropriate design object with the new weighted dataset
  design <- srvyr::as_survey_design(
    ids = sdmvpsu,             # Primary sampling units
    strata = sdmvstra,         # Strata
    weights = design_weight,   # Type of weight to use
    nest = TRUE,
    .data = survey_dat
  )

  return(design)

}
