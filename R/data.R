#----------------------------------------------------------------------------------------
#' Get CDC Documentation URL for NHANES Table
#'
#' Constructs and returns the full CDC documentation URL for a given NHANES
#' table. The function handles table names with or without cycle suffixes
#' (e.g., "DEMO_J" for 2017-2018 or "DEMO" for 1999-2000) and automatically
#' maps the suffix to the appropriate survey cycle year.
#'
#' @param table Character. The table where variable information is needed.
#'   Can include cycle suffix (e.g., "DEMO_J") or not (e.g., "DEMO").
#'   Not case-sensitive.
#'
#' @return Character string (invisibly). Full URL to CDC data documentation,
#'   codebook, and frequencies is returned invisibly and also printed to the
#'   console via message() for interactive use.
#'
#' @export
#' @examples
#' # These examples will run and display URLs
#' get_url("DEMO_J") # Demographics 2017-2018
#' get_url("diq_j") # Case-insensitive: Diabetes 2017-2018
#' get_url("DIQ") # No suffix = 1999-2000 cycle
#'
#' # Capture the URL for programmatic use
#' url <- get_url("BMX_J")
#'
#' @family search and lookup functions
#' @seealso \code{\link{term_search}}, \code{\link{var_search}}
get_url <- function(table) {
  # Normalize to uppercase
  table <- toupper(table)

  # Extract suffix if present (pattern: TABLENAME_X where X is a letter)
  if (grepl("_[A-Z]$", table)) {
    parts <- strsplit(table, "_")[[1]]
    suffix <- parts[length(parts)]
  } else {
    suffix <- ""
  }

  # Get year from suffix
  year <- .get_year_from_suffix(suffix) # nolint: object_usage_linter.

  if (is.null(year)) {
    warning(sprintf(
      paste0(
        "Unrecognized table suffix '_%s'. ",
        "Valid suffixes: A-J, L (excluding K). ",
        "Defaulting to 1999."
      ),
      suffix
    ))
    year <- 1999L
  }

  # Construct CDC documentation URL
  url <- sprintf(
    "https://wwwn.cdc.gov/nchs/data/nhanes/public/%d/datafiles/%s.htm",
    year,
    table
  )

  # Message the URL and return invisibly
  message(url)
  invisible(url)
}

#----------------------------------------------------------------------------------------
#' Search NHANES Variables by Term or Phrase
#'
#' A convenience wrapper around \code{nhanesA::nhanesSearch} that returns
#' a simplified, concise output focused on variable names, descriptions,
#' and survey years. Results are sorted by year (most recent first) and
#' then by variable name.
#'
#' @param var Character. Search term or phrase to find in variable names
#'   or descriptions. Case-insensitive. Special regex characters are
#'   automatically escaped for literal matching.
#'
#' @return A data.frame with 4 columns:
#'   \itemize{
#'     \item \code{Variable.Name}: NHANES variable code
#'     \item \code{Variable.Description}: Description of the variable
#'     \item \code{Data.File.Name}: Name of the data file containing the variable
#'     \item \code{Begin.Year}: Starting year of the survey cycle (numeric)
#'   }
#'   Results are sorted by \code{Begin.Year} (descending) then \code{Variable.Name}.
#'   Returns an empty data.frame with correct structure if no matches found.
#'
#' @examples
#' \donttest{
#' # Search for diabetes-related variables
#' term_search("diabetes")
#'
#' # Search for blood pressure measurements
#' term_search("blood pressure")
#'
#' # Search for demographic variables
#' term_search("age")
#'
#' # Handles special characters safely
#' term_search("weight (kg)")
#' }
#'
#' @family search and lookup functions
#' @seealso \code{\link{var_search}} for searching by exact variable name,
#'   \code{\link{get_url}} for getting documentation URLs,
#'   \code{\link[nhanesA]{nhanesSearch}} for the underlying search function
#' @importFrom nhanesA nhanesSearch
#' @importFrom dplyr select arrange desc mutate
#' @export
term_search <- function(var) {
  # Input validation
  if (missing(var)) {
    stop("Argument 'var' is required", call. = FALSE)
  }

  if (!is.character(var) || length(var) != 1) {
    stop("'var' must be a single character string", call. = FALSE)
  }

  if (nchar(var) == 0) {
    stop("'var' must be a non-empty string", call. = FALSE)
  }

  # Perform search with comprehensive error handling
  result <- tryCatch(
    {
      # First attempt: search as-is
      tryCatch(
        nhanesA::nhanesSearch(var, ignore.case = TRUE),
        error = function(e) {
          # If regex error, try escaping special characters
          if (grepl("invalid regular expression", e$message, ignore.case = TRUE)) {
            var_escaped <- gsub("([.|()\\^{}+$*?\\[\\]])", "\\\\\\1", var)
            nhanesA::nhanesSearch(var_escaped, ignore.case = TRUE)
          } else {
            # Re-throw to outer tryCatch
            stop(e)
          }
        }
      )
    },
    error = function(e) {
      # Handle API/network failures with helpful message
      message(sprintf(
        paste0(
          "\nUnable to search NHANES database ",
          "for '%s'.\nThis may be due to:",
          "\n  - NHANES API temporarily unavailable",
          "\n  - Network connectivity issues",
          "\n  - Service maintenance",
          "\n\nPlease try again later or ",
          "check your internet connection."
        ),
        var
      ))
      # Return empty data.frame with correct structure
      data.frame(
        Variable.Name = character(0),
        Variable.Description = character(0),
        Data.File.Name = character(0),
        Begin.Year = numeric(0),
        stringsAsFactors = FALSE
      )
    }
  )

  # Handle NULL or empty results (no matches found - this is different from API errors)
  # Check if already returned from error handler (will be empty data.frame)
  if (is.data.frame(result) && nrow(result) == 0) {
    # Already handled in error case, just return it
    return(result)
  }

  if (is.null(result)) {
    message(sprintf("No NHANES variables found matching: '%s'", var))
    return(
      data.frame(
        Variable.Name = character(0),
        Variable.Description = character(0),
        Data.File.Name = character(0),
        Begin.Year = numeric(0),
        stringsAsFactors = FALSE
      )
    )
  }


  # Select columns and ensure Begin.Year is numeric
  # nolint start: object_usage_linter.
  result |>
    dplyr::select(1:3, Begin.Year) |>
    dplyr::mutate(Begin.Year = as.numeric(Begin.Year)) |>
    dplyr::arrange(dplyr::desc(`Begin.Year`), `Variable.Name`)
  # nolint end
}

#----------------------------------------------------------------------------------------
#' Search for NHANES Variable by Exact Name
#'
#' A convenience wrapper around \code{nhanesA::nhanesSearchVarName} that
#' searches for variables by exact variable name match. The function
#' automatically converts input to uppercase to match NHANES naming conventions.
#' Use this when you know the variable code; use \code{term_search()} for
#' text-based searches.
#'
#' @param var Character. Variable name to search for. Will be automatically
#'   converted to uppercase. Not case-sensitive.
#'
#' @return A data.frame showing all occurrences of the variable across
#'   survey cycles, including variable descriptions, data file names, and
#'   years available. Returns an empty data.frame with appropriate structure
#'   if the variable is not found.
#'
#' @examples
#' \donttest{
#' # Search for specific variable (case-insensitive)
#' var_search("RIAGENDR") # Gender variable
#' var_search("ridageyr") # Age variable (auto-converted to uppercase)
#'
#' # See where glucose variables appear
#' var_search("LBXGLU")
#' }
#'
#' @family search and lookup functions
#' @seealso \code{\link{term_search}} for text-based searches,
#'   \code{\link{get_url}} for documentation URLs,
#'   \code{\link[nhanesA]{nhanesSearchVarName}} for the underlying function
#' @importFrom nhanesA nhanesSearchVarName
#' @importFrom stringr str_to_upper
#' @export
var_search <- function(var) {
  # Input validation
  if (missing(var)) {
    stop("Argument 'var' is required", call. = FALSE)
  }

  if (!is.character(var) || length(var) != 1) {
    stop("'var' must be a single character string", call. = FALSE)
  }

  if (nchar(var) == 0) {
    stop("'var' must be a non-empty string", call. = FALSE)
  }

  # Convert to uppercase and search with error handling
  var_upper <- stringr::str_to_upper(var)

  result <- tryCatch(
    nhanesA::nhanesSearchVarName(var_upper),
    error = function(e) {
      # Handle API/network failures with helpful message
      message(sprintf(
        paste0(
          "\nUnable to search NHANES database ",
          "for variable '%s'.\nThis may be due to:",
          "\n  - NHANES API temporarily unavailable",
          "\n  - Network connectivity issues",
          "\n  - Service maintenance",
          "\n\nPlease try again later or ",
          "check your internet connection."
        ),
        var_upper
      ))
      # Return empty data.frame with correct structure
      data.frame(
        Variable.Name = character(0),
        Variable.Description = character(0),
        Data.File.Name = character(0),
        Data.File.Description = character(0),
        Begin.Year = numeric(0),
        EndYear = numeric(0),
        Component = character(0),
        UseConstraints = character(0),
        stringsAsFactors = FALSE
      )
    }
  )

  # Handle NULL or empty results (variable not found - this is different from API errors)
  # Check if already returned from error handler (will be empty data.frame)
  if (is.data.frame(result) && nrow(result) == 0) {
    # Already handled in error case, just return it
    return(result)
  }

  if (is.null(result)) {
    message(sprintf("No NHANES variable found with name: '%s'", var_upper))
    return(
      data.frame(
        Variable.Name = character(0),
        Variable.Description = character(0),
        Data.File.Name = character(0),
        Data.File.Description = character(0),
        Begin.Year = numeric(0),
        EndYear = numeric(0),
        Component = character(0),
        UseConstraints = character(0),
        stringsAsFactors = FALSE
      )
    )
  }

  result
}

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
#' @param save Logical. If TRUE (default), saves the combined data as both
#'   .rda and .parquet files in data/raw/R/ and data/raw/parquet/ respectively.
#'   Directories are created if they don't exist.
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
#' @examples
#' \dontrun{
#' # Internal use only - called via nhanesdata:::pull_nhanes()
#' demo_data <- pull_nhanes("DEMO")
#'
#' # Pull specific variables only
#' bmi_data <- pull_nhanes(
#'   nhanes_table = "BMX",
#'   selected_variables = c("SEQN", "BMXWT", "BMXHT", "BMXBMI")
#' )
#'
#' # Pull without saving files
#' temp_data <- pull_nhanes("DIQ", save = FALSE)
#' }
#'
#' @noRd
pull_nhanes <- function(nhanes_table, selected_variables = NULL, save = TRUE) {
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
  # Suffixes B through J cover 2001-2017; L covers 2021-2023.
  # Suffix K (2019-2020) is intentionally skipped due to COVID-19 data

  # collection issues that compromised data quality.
  table_suffixes <- c(LETTERS[2:10], LETTERS[12])

  start_dfr <- tibble::tibble(
    code = c(nhanes_table, paste0(nhanes_table, "_", table_suffixes)),
    year = c(seq(1999, 2017, by = 2), 2021)
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
    current_data <- .translate_numeric_columns( # nolint: object_usage_linter.
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
    # and resolves them safely. See .harmonize_column_types() in R/utils.R
    # for the full set of type resolution rules.
    if (nrow(combined_data) == 0) {
      combined_data <- current_data
    } else {
      harmonized <- .harmonize_column_types( # nolint: object_usage_linter.
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
      year = as.integer(year), # nolint: object_usage_linter.
      seqn = as.integer(seqn) # nolint: object_usage_linter.
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

#-------------------------------------------------------
#' Read NHANES Data from Cloud Storage
#'
#' Downloads pre-processed NHANES data files from cloud storage. Data includes
#' all survey cycles (1999-2023) automatically merged and harmonized, with
#' quarterly updates.
#'
#' @param dataset Character. NHANES dataset base name (e.g., "trigly", "demo").
#'   **Case-insensitive** - use 'demo', 'DEMO', or 'Demo' interchangeably.
#'   Must be a single string (length 1). Leading/trailing whitespace is
#'   automatically trimmed.
#'
#' @details
#' This function downloads NHANES datasets from cloud storage (hosted at
#' nhanes.kylegrealis.com). All datasets combine multiple survey cycles with
#' automatic type harmonization. Data is updated quarterly via automated
#' workflows that pull fresh data from CDC servers.
#'
#' **Dataset names are case-insensitive throughout this package.** Use uppercase
#' (matches CDC documentation) or lowercase (easier to type) - both work identically.
#'
#' **Error handling:** The function validates inputs and provides informative
#' error messages if the dataset fails to load (e.g., network issues, non-existent
#' datasets, misspelled names). Error messages include the attempted URL and
#' suggestions for troubleshooting.
#'
#' @return A tibble containing the requested NHANES dataset across all
#'   available survey cycles. Always includes \code{year} and \code{seqn}
#'   columns plus dataset-specific variables.
#'
#' @examples
#' # All case variations work identically:
#' trigly <- read_nhanes("trigly") # Lowercase
#' demo <- read_nhanes("DEMO") # Uppercase
#' acq <- read_nhanes("Acq") # Mixed case
#'
#' # Load multiple datasets
#' datasets <- c("demo", "BPX", "bmx") |>
#'   purrr::map(read_nhanes)
#'
#' @export
read_nhanes <- function(dataset) {
  # Input validation
  if (!is.character(dataset) || length(dataset) != 1) {
    stop(
      "`dataset` must be a single character string, not ",
      class(dataset)[1],
      call. = FALSE
    )
  }

  dataset <- tolower(trimws(dataset))

  # Construct URL
  url <- sprintf(
    "https://nhanes.kylegrealis.com/%s.parquet",
    dataset
  )

  message(sprintf("Loading: %s", toupper(dataset)))

  # Attempt download with error handling
  ds <- tryCatch(
    arrow::read_parquet(url),
    error = function(e) {
      stop(
        sprintf(
          paste0(
            "Failed to load dataset '%s'.",
            "\n  URL: %s",
            "\n  Error: %s",
            "\n  Did you misspell the dataset name?"
          ),
          toupper(dataset),
          url,
          conditionMessage(e)
        ),
        call. = FALSE
      )
    }
  )

  message(sprintf(
    "%s complete! (%s rows)",
    toupper(dataset),
    format(nrow(ds), big.mark = ",")
  ))
  ds
}
