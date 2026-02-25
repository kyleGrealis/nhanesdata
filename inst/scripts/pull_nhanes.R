# Internal Data Pipeline Functions
#
# This file contains data processing functions used by the automated NHANES
# data update workflow (workflow_update.R). These functions are NOT part of
# the user-facing package API and are not subject to CRAN's default file
# writing restrictions.
#
# Functions in this file:
#   - pull_nhanes(): Downloads and harmonizes NHANES data across cycles
#   - .harmonize_column_types(): Type reconciliation for bind_rows()
#   - .translate_numeric_columns(): Cross-cycle label application
#   - .coerce_na_column(): Type coercion for all-NA columns

#----------------------------------------------------------------------------------------
#' Pull NHANES Data Across Multiple Survey Cycles
#'
#' Downloads and combines NHANES data for a specified table across all
#' available survey cycles from CDC servers. The function automatically
#' handles type mismatches between cycles, adds cycle year identifiers,
#' and optionally saves the combined data in multiple formats.
#'
#' This is an **internal function** used by package maintainers in automated
#' data update workflows (see inst/scripts/workflow_update.R). End users should
#' use \code{read_nhanes()} to load pre-processed data from cloud storage.
#'
#' @param nhanes_table Character. NHANES table base name (e.g., "DEMO", "BMX").
#'   Not case-sensitive. Do not include cycle suffixes - the function
#'   automatically queries all cycles.
#'
#' @param selected_variables Character vector. Optional. Variable names to
#'   extract from each cycle. If NULL (default), all variables are included.
#'   Variable names will be automatically converted to uppercase.
#'
#' @param save Logical. If TRUE, saves the combined data as both .rda and
#'   .parquet files in data/raw/R/ and data/raw/parquet/ respectively.
#'   Directories are created if they don't exist. Default is FALSE (changed
#'   from TRUE in v0.2.1 to comply with CRAN policy).
#'
#' @details
#' The function queries NHANES cycles from 1999-2000 through 2017-2018, plus
#' the 2021-2023 cycle. The 2019-2020 cycle (suffix K) is intentionally
#' skipped due to data collection issues during COVID-19.
#'
#' Cycle suffixes used: B (2001-2002) through J (2017-2018), and L (2021-2023).
#' Tables without suffixes represent the 1999-2000 cycle.
#'
#' The function automatically:
#' \itemize{
#'   \item Adds a \code{year} column (survey cycle start year)
#'   \item Ensures \code{seqn} (respondent ID) is present
#'   \item Converts all variable names to lowercase via
#'     \code{janitor::clean_names()}
#'   \item Applies cross-cycle translation so categorical variables have
#'     human-readable labels in every cycle, even when the CDC codebook was
#'     unavailable for a particular cycle
#'   \item Converts all factor columns to character before binding to avoid
#'     factor-level conflicts and the data corruption caused by
#'     \code{as.double(factor)} returning level indices
#'   \item Harmonizes remaining type mismatches (integer vs double -> double;
#'     any factor involvement -> character; everything else -> character)
#' }
#'
#' @section Type harmonization:
#' \code{nhanesA::nhanes()} returns categorical variables as factors with text
#' labels in most cycles, but some cycles lack a parseable CDC codebook and
#' return raw numeric codes instead. This function handles the mismatch in
#' three stages:
#' \enumerate{
#'   \item \strong{Cross-cycle translation}: Numeric columns that have a
#'     translation table available from any sibling cycle are converted to
#'     text labels via \code{.translate_numeric_columns()}.
#'   \item \strong{Factor-to-character conversion}: All remaining factor
#'     columns are converted to character to prevent \code{bind_rows()} from
#'     encountering factor-level conflicts.
#'   \item \strong{Proactive type harmonization}: Before each
#'     \code{bind_rows()} call, \code{.harmonize_column_types()} compares
#'     column classes and coerces mismatched columns to a common type.
#' }
#'
#' @return A tibble with combined data from all available cycles. Always includes:
#'   \itemize{
#'     \item \code{year}: Integer. Survey cycle start year
#'     \item \code{seqn}: Integer. Respondent sequence number (unique ID)
#'     \item Additional columns from the requested NHANES table (lowercase names)
#'   }
#'
#' @keywords internal
pull_nhanes <- function(nhanes_table, selected_variables = NULL, save = FALSE) {
  # Check for required Suggests packages (internal function only)
  required_pkgs <- c("janitor", "fs", "scales")
  missing_pkgs <- required_pkgs[
    !sapply(required_pkgs, requireNamespace, quietly = TRUE)
  ]

  if (length(missing_pkgs) > 0) {
    stop(
      "The following packages are required for pull_nhanes(): ",
      paste(missing_pkgs, collapse = ", "), "\n",
      "Install with: install.packages(c(",
      paste(shQuote(missing_pkgs), collapse = ", "), "))",
      call. = FALSE
    )
  }

  nhanes_table <- stringr::str_to_upper(nhanes_table)
  message(sprintf("\nDataset: %s", nhanes_table))

  # Build the list of table codes and their corresponding survey years.
  # Suffixes B through J cover 2001-2017; L through P cover 2021-2029.
  # Suffix K (2019-2020) is intentionally skipped due to COVID-19 data
  # collection issues that compromised data quality.
  # Future-proofed through 2029 to automatically detect new cycles as CDC releases them.
  table_suffixes <- c(LETTERS[2:10], LETTERS[12:16])

  start_dfr <- tibble::tibble(
    code = c(nhanes_table, paste0(nhanes_table, "_", table_suffixes)),
    year = c(seq(1999, 2017, by = 2), seq(2021, 2029, by = 2))
  )

  # ---------------------------------------------------------------------------
  # Build reference translation tables for cross-cycle label application.
  #
  # nhanesA::nhanes() calls nhanesTranslate() internally to convert numeric
  # CDC codes to human-readable factor labels (e.g., 1 -> "Male"). However,
  # some cycles lack a parseable CDC codebook, so certain columns come back
  # as plain numeric in those cycles. To ensure every cycle has labels, we
  # cache a set of translation tables from a cycle that DOES have them and
  # apply those mappings to untranslated numeric columns.
  #
  # We try the most recent cycles first (L, J, I, ...) because their
  # codebooks tend to be most complete and up-to-date.
  # ---------------------------------------------------------------------------
  reference_translations <- NULL
  ref_suffixes <- rev(c("", table_suffixes)) # try newest first

  for (ref_suffix in ref_suffixes) {
    ref_table <- if (ref_suffix == "") {
      nhanes_table
    } else {
      paste0(nhanes_table, "_", ref_suffix)
    }

    reference_translations <- tryCatch(
      suppressMessages(suppressWarnings(
        nhanesA::nhanesTranslate(ref_table)
      )),
      error = function(e) NULL
    )

    has_translations <- !is.null(reference_translations) &&
      length(reference_translations) > 0
    if (has_translations) {
      message(sprintf(
        "  Cached translation tables from %s (%d columns)",
        ref_table, length(reference_translations)
      ))
      break
    }
  }

  # ---------------------------------------------------------------------------
  # Main loop: download each cycle, translate, harmonize, and bind.
  # ---------------------------------------------------------------------------
  combined_data <- tibble::tibble()
  skipped_cycles <- character(0)

  for (i in seq_len(nrow(start_dfr))) {
    code <- start_dfr$code[i]
    yr <- start_dfr$year[i]

    message(sprintf("Processing NHANES data for year: %s", yr))

    # Retry on errors (network failures, timeouts) but NOT on NULL
    # returns. nhanesA::nhanes() returns NULL for tables that genuinely
    # don't exist in a cycle (e.g., AGQ only exists 1999-2005), which
    # is normal and should not trigger retries or be flagged.
    max_retries <- 3
    retry_delay <- getOption("nhanesdata.retry_delay", 5)
    data <- NULL
    last_error <- NULL

    for (attempt in seq_len(max_retries)) {
      result <- tryCatch(
        list(data = nhanesA::nhanes(code), ok = TRUE),
        error = function(e) list(data = NULL, ok = FALSE, msg = e$message)
      )

      if (result$ok) {
        data <- result$data
        break
      }

      # Only retry on actual errors (network, timeout, etc.)
      last_error <- result$msg
      if (attempt < max_retries) {
        message(sprintf(
          "  Attempt %d/%d errored for %s: %s. Retrying in %ds...",
          attempt, max_retries, code, last_error, retry_delay
        ))
        Sys.sleep(retry_delay)
      }
    }

    if (!is.null(last_error) && is.null(data)) {
      # All retries exhausted on an actual error
      message(sprintf(
        "Dataset %s failed after %d attempts: %s",
        code, max_retries, last_error
      ))
      skipped_cycles <- c(skipped_cycles, code)
      next
    }

    if (is.null(data)) {
      message(sprintf("Dataset %s not available, skipping...", code))
      next
    }

    # Prepare the cycle data: add year column, clean column names
    if (is.null(selected_variables)) {
      current_data <- data |>
        dplyr::mutate(year = yr, .before = 1) |>
        janitor::clean_names()
    } else {
      current_data <- data |>
        dplyr::select(
          dplyr::any_of(stringr::str_to_upper(selected_variables))
        ) |>
        dplyr::mutate(year = yr, .before = 1) |>
        janitor::clean_names()
    }

    # Step 1: Apply cached translation tables to any numeric columns that
    # nhanesA failed to translate in this cycle. This ensures columns like
    # BMIWT get labels ("Could not obtain", "Clothing", "Medical appliance")
    # even in cycles where the CDC codebook was unavailable.
    current_data <- .translate_numeric_columns(
      current_data, reference_translations
    )

    # Step 2: Convert all factor columns to character. This avoids factor-level
    # conflicts across cycles and prevents the data corruption that occurs when
    # as.double() is called on a factor (which returns level indices, not the
    # original CDC codes).
    for (col_name in names(current_data)) {
      if (is.factor(current_data[[col_name]])) {
        current_data[[col_name]] <- as.character(current_data[[col_name]])
      }
    }

    # Step 3: Proactively harmonize column types before binding. This catches
    # remaining mismatches (integer vs double, character vs numeric, etc.)
    # and resolves them safely. See .harmonize_column_types() for the full
    # set of type resolution rules.
    if (nrow(combined_data) == 0) {
      combined_data <- current_data
    } else {
      harmonized <- .harmonize_column_types(
        combined_data, current_data
      )
      combined_data <- harmonized$existing
      current_data <- harmonized$new

      # bind_rows() with a safety net for any edge case we didn't anticipate.
      # After proactive harmonization this should never fire, but if it does,
      # we fall back to converting all mismatched columns to character.
      combined_data <- tryCatch(
        dplyr::bind_rows(combined_data, current_data),
        error = function(e) {
          warning(sprintf(
            "bind_rows() failed after harmonization for %s (year %s): %s",
            code, yr, conditionMessage(e)
          ))
          common_cols <- intersect(
            names(combined_data), names(current_data)
          )
          for (col in common_cols) {
            if (col %in% c("year", "seqn")) next
            types_differ <- class(combined_data[[col]])[1] !=
              class(current_data[[col]])[1]
            if (types_differ) {
              combined_data[[col]] <<- as.character(
                combined_data[[col]]
              )
              current_data[[col]] <<- as.character(
                current_data[[col]]
              )
            }
          }
          dplyr::bind_rows(combined_data, current_data)
        }
      )
    }
  }

  # Handle case where all cycles failed
  if (nrow(combined_data) == 0) {
    warning(sprintf(
      "%s: No data retrieved from any cycle.", nhanes_table
    ), call. = FALSE)
    mapped_dfr <- combined_data
    if (length(skipped_cycles) > 0) {
      attr(mapped_dfr, "skipped_cycles") <- skipped_cycles
    }
    return(mapped_dfr)
  }

  # Enforce canonical types for structural columns
  mapped_dfr <- combined_data |>
    dplyr::mutate(
      year = as.integer(year),
      seqn = as.integer(seqn)
    )

  if (save) {
    if (!fs::dir_exists("data/raw/R")) {
      fs::dir_create("data/raw/R", recurse = TRUE)
    }
    if (!fs::dir_exists("data/raw/parquet")) {
      fs::dir_create("data/raw/parquet", recurse = TRUE)
    }

    assign(tolower(nhanes_table), mapped_dfr)
    save(
      list = tolower(nhanes_table),
      file = sprintf("data/raw/R/%s.rda", tolower(nhanes_table))
    )

    arrow::write_parquet(
      mapped_dfr,
      sprintf("data/raw/parquet/%s.parquet", tolower(nhanes_table))
    )
  }

  message(sprintf(
    "Number of rows for %s: %s",
    nhanes_table,
    scales::comma(nrow(mapped_dfr))
  ))

  if (length(skipped_cycles) > 0) {
    warning(sprintf(
      "%s: %d cycle(s) skipped after retries: %s",
      nhanes_table,
      length(skipped_cycles),
      paste(skipped_cycles, collapse = ", ")
    ), call. = FALSE)
    attr(mapped_dfr, "skipped_cycles") <- skipped_cycles
  }

  mapped_dfr
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
#'     \emph{indices}, not original values - this caused data corruption in
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

    # Nothing to do when types already match - unless both are factors,
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

    # Drop the "." (missing) row - R already represents these as NA
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
