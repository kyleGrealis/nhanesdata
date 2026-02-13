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

#----------------------------------------------------------------------------------------
#' Internal: Coerce an All-NA Column to a Target Type
#'
#' Converts a vector of entirely NA values to a specified R class.
#' Used by \code{.harmonize_column_types()} when one side of a merge is
#' all-NA and needs to adopt the other side's type for \code{bind_rows()}
#' compatibility. This avoids the need for the \pkg{methods} package.
#'
#' @param x Vector. Must be entirely NA (caller is responsible for checking).
#' @param target_class Character. The class name to coerce to, as returned by
#'   \code{class(y)[1]} on the non-NA column (e.g., "numeric", "character",
#'   "integer", "logical").
#'
#' @return A vector of the same length as \code{x}, with all values NA, but
#'   with the storage type matching \code{target_class}.
#'
#' @keywords internal
#' @noRd
.coerce_na_column <- function(x, target_class) {
  n <- length(x)
  switch(target_class,
    "numeric"   = rep(NA_real_, n),
    "double"    = rep(NA_real_, n),
    "integer"   = rep(NA_integer_, n),
    "character" = rep(NA_character_, n),
    "logical"   = rep(NA, n),
    "factor"    = factor(rep(NA, n)),
    "ordered"   = ordered(rep(NA, n)),
    # Fallback: character is always safe for unknown types
    rep(NA_character_, n)
  )
}

#----------------------------------------------------------------------------------------
#' Internal: Harmonize Column Types Between Two Data Frames
#'
#' Compares column types across two data frames (representing different NHANES
#' survey cycles) and coerces mismatched columns to a common type so that
#' \code{dplyr::bind_rows()} can combine them without error or data loss.
#'
#' Called proactively before every \code{bind_rows()} in
#' \code{pull_nhanes()}, rather than reactively inside an error handler.
#'
#' @section Type resolution rules:
#' \describe{
#'   \item{factor vs factor}{Both to character (avoids factor-level conflicts
#'     across cycles).}
#'   \item{factor vs numeric}{Both to character. The factor keeps its text
#'     labels; the numeric keeps its value as a string (e.g. \code{3} becomes
#'     \code{"3"}). Using \code{as.double()} on a factor returns level
#'     \emph{indices}, not original values -- this caused data corruption in
#'     earlier versions.}
#'   \item{factor vs character}{Factor to character.}
#'   \item{integer vs double (no factors)}{Both to double.}
#'   \item{all-NA column}{Coerced to match the other side's type via
#'     \code{.coerce_na_column()}. This is necessary because
#'     \code{bind_rows()} does not implicitly coerce between typed NAs
#'     (e.g., character NA vs double will error). Commonly occurs when a
#'     column exists in some NHANES cycles but not others.}
#'   \item{anything else}{Both to character (safe fallback).}
#' }
#'
#' @param existing_df Data frame. The accumulated data from prior cycles.
#' @param new_df Data frame. The current cycle being appended.
#' @param skip_cols Character vector. Column names to leave untouched.
#'   Defaults to \code{c("year", "seqn")} because those are enforced as
#'   integer after the merge loop.
#'
#' @return A named list with two elements:
#'   \describe{
#'     \item{\code{existing}}{The \code{existing_df} with harmonized types.}
#'     \item{\code{new}}{The \code{new_df} with harmonized types.}
#'   }
#'
#' @keywords internal
#' @noRd
.harmonize_column_types <- function(
  existing_df,
  new_df,
  skip_cols = c("year", "seqn")
) {
  common_cols <- intersect(names(existing_df), names(new_df))

  for (col in common_cols) {
    if (col %in% skip_cols) next

    existing_class <- class(existing_df[[col]])[1]
    new_class <- class(new_df[[col]])[1]

    existing_is_factor <- is.factor(existing_df[[col]])
    new_is_factor <- is.factor(new_df[[col]])

    # Nothing to do when types already match -- unless both are factors,
    # which can have incompatible levels across cycles. We convert all
    # factors to character for consistency and safety.
    if (existing_class == new_class && !existing_is_factor) next

    # When one side is entirely NA, adopt the other side's type. NA values
    # are type-agnostic in R, so this conversion is always lossless. We
    # cannot simply skip and let bind_rows() handle it because bind_rows()
    # is strict about type matching (e.g., character NA vs double will
    # error). This commonly occurs when a column (like BMIHEAD) exists in
    # some NHANES cycles but not others. bind_rows() fills the missing
    # column with typed NAs that may clash with the column's real type in
    # a later cycle.
    if (all(is.na(existing_df[[col]]))) {
      existing_df[[col]] <- .coerce_na_column(
        existing_df[[col]], new_class
      )
      next
    }
    if (all(is.na(new_df[[col]]))) {
      new_df[[col]] <- .coerce_na_column(
        new_df[[col]], existing_class
      )
      next
    }

    existing_is_numeric <- is.numeric(existing_df[[col]]) && !existing_is_factor
    new_is_numeric <- is.numeric(new_df[[col]]) && !new_is_factor

    if (existing_is_factor || new_is_factor) {
      # --- Any mismatch involving a factor resolves to character ---
      #
      # Why not as.double()? Factors store integer indices internally, so
      # as.double(factor) returns 1, 2, 3, ... regardless of the original
      # CDC codes (which may be 1, 3, 4 or 7, 9, 77). Converting both
      # sides to character preserves factor labels verbatim and turns
      # numeric codes into their string representation.
      if (existing_is_factor && new_is_factor) {
        reason <- "factor vs factor (different levels)"
      } else if (existing_is_factor && new_is_numeric) {
        reason <- sprintf("factor vs %s", new_class)
      } else if (new_is_factor && existing_is_numeric) {
        reason <- sprintf("%s vs factor", existing_class)
      } else {
        reason <- sprintf("%s vs %s (factor involved)", existing_class, new_class)
      }
      message(sprintf(
        "  [harmonize] %s: %s -> character", col, reason
      ))
      existing_df[[col]] <- as.character(existing_df[[col]])
      new_df[[col]] <- as.character(new_df[[col]])
    } else if (existing_is_numeric && new_is_numeric) {
      # --- integer vs double (no factors) -> double ---
      message(sprintf(
        "  [harmonize] %s: %s vs %s -> double", col, existing_class, new_class
      ))
      existing_df[[col]] <- as.double(existing_df[[col]])
      new_df[[col]] <- as.double(new_df[[col]])
    } else {
      # --- Anything else (character vs numeric, logical vs numeric, etc.) ---
      message(sprintf(
        "  [harmonize] %s: %s vs %s -> character", col, existing_class, new_class
      ))
      existing_df[[col]] <- as.character(existing_df[[col]])
      new_df[[col]] <- as.character(new_df[[col]])
    }
  }

  list(existing = existing_df, new = new_df)
}

#----------------------------------------------------------------------------------------
#' Internal: Apply Cross-Cycle Translation to Untranslated Numeric Columns
#'
#' When \code{nhanesA::nhanes()} returns a column as plain numeric (because the
#' CDC codebook was unavailable for that cycle), this function applies a
#' translation table obtained from a sibling cycle to convert numeric codes into
#' human-readable text labels.
#'
#' For example, BMX_G (2011) returns \code{BMIWT} as numeric codes
#' \code{1, 3, 4}. The codebook from BMX_J (2017) maps those to
#' \code{"Could not obtain"}, \code{"Clothing"}, \code{"Medical appliance"}.
#' This function applies that mapping so every cycle has labels.
#'
#' @param current_data Data frame. One cycle's data, already pulled via
#'   \code{nhanesA::nhanes()} with \code{translated = TRUE}.
#' @param reference_translations Named list of data frames, as returned by
#'   \code{nhanesA::nhanesTranslate()}. Each element is named by column and
#'   contains \code{Code.or.Value} and \code{Value.Description} columns.
#'   Columns present in this list but already translated (i.e. already a
#'   factor in \code{current_data}) are skipped.
#'
#' @return The input data frame with previously-numeric coded columns converted
#'   to character vectors containing text labels. Codes that do not appear in
#'   the translation table are kept as-is (converted to their string
#'   representation).
#'
#'   Columns are left unchanged if they:
#'   \itemize{
#'     \item are already factors or character (already translated)
#'     \item are not numeric
#'     \item are entirely NA
#'     \item have no matching translation table
#'     \item have a "Range of Values" entry in their translation table,
#'       indicating a continuous variable (e.g. RIDAGEYR, INDFMPIR).
#'       Translating these would corrupt the numeric data by converting
#'       top-coded values to text labels while leaving other values as
#'       numeric strings.
#'   }
#'
#' @keywords internal
#' @noRd
.translate_numeric_columns <- function(current_data, reference_translations) {
  if (is.null(reference_translations) || length(reference_translations) == 0) {
    return(current_data)
  }

  for (col_name in names(reference_translations)) {
    # Column names in reference_translations are UPPERCASE (from nhanesA).
    # current_data has lowercase names (from janitor::clean_names()).
    col_lower <- tolower(col_name)

    if (!(col_lower %in% names(current_data))) next

    col_vec <- current_data[[col_lower]]

    # Skip columns that nhanesA already translated (factor) or that are
    # character (already labeled from a prior harmonization step)
    if (is.factor(col_vec) || is.character(col_vec)) next

    # Skip columns that are not numeric (nothing to translate)
    if (!is.numeric(col_vec)) next

    # Skip columns that are entirely NA (no values to translate)
    if (all(is.na(col_vec))) next

    # Build code-to-label lookup from the translation table.
    # nhanesTranslate() returns rows like:
    #   Code.or.Value  Value.Description
    #   1              "Could not obtain"
    #   3              "Clothing"
    #   .              "Missing"
    tt <- reference_translations[[col_name]]
    if (is.null(tt) || nrow(tt) == 0) next

    # Drop the "." (missing) row -- R already represents these as NA
    tt <- tt[tt$Code.or.Value != ".", , drop = FALSE]
    if (nrow(tt) == 0) next

    # Skip continuous variables. The CDC codebook marks these with a
    # "Range of Values" entry (e.g., "0 to 79" for RIDAGEYR). Applying
    # label translations to continuous data would corrupt it: the top-coded
    # value (e.g., 80 -> "80 years of age and over") gets a text label
    # while every other value becomes its string representation, turning
    # the entire numeric column into unusable character data.
    has_range <- any(
      grepl("Range of Values", tt$Value.Description, fixed = TRUE)
    )
    if (has_range) next

    codes <- suppressWarnings(as.double(tt$Code.or.Value))
    labels <- tt$Value.Description

    # Drop any rows where Code.or.Value was not numeric
    # (e.g., text-based codes that slipped through)
    valid <- !is.na(codes)
    codes <- codes[valid]
    labels <- labels[valid]
    if (length(codes) == 0) next

    # Apply the mapping: numeric code -> text label.
    # Values not in the translation table become their string representation.
    translated <- as.character(col_vec)
    for (j in seq_along(codes)) {
      mask <- !is.na(col_vec) & col_vec == codes[j]
      translated[mask] <- labels[j]
    }

    current_data[[col_lower]] <- translated
    message(sprintf(
      "  [translate] %s: applied %d code-to-label mappings from reference cycle",
      col_lower, length(codes)
    ))
  }

  current_data
}
