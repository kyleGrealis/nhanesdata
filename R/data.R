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
#' # Search for diabetes-related variables (showing first 5 results)
#' term_search("diabetes") |> head(5)
#'
#' # Search for blood pressure measurements (showing first 5 results)
#' term_search("blood pressure") |> head(5)
#' }
#'
#' @family search and lookup functions
#' @seealso \code{\link{var_search}} for searching by exact variable name,
#'   \code{\link{get_url}} for getting documentation URLs,
#'   \code{\link[nhanesA]{nhanesSearch}} for the underlying search function
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
#' @return A character vector of CDC table names containing the variable
#'   (e.g., \code{"DEMO"}, \code{"DEMO_B"}, \code{"DEMO_C"}).
#'   Returns \code{character(0)} if the variable is not found.
#'
#' @examples
#' \donttest{
#' # Search for specific variable (case-insensitive)
#' var_search("RIDAGEYR") # Age variable across all DEMO cycles
#' var_search("BPXSY1") # Systolic blood pressure
#' }
#'
#' @family search and lookup functions
#' @seealso \code{\link{term_search}} for text-based searches,
#'   \code{\link{get_url}} for documentation URLs,
#'   \code{\link[nhanesA]{nhanesSearchVarName}} for the underlying function
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

#-------------------------------------------------------
#' Read NHANES Data from Cloud Storage
#'
#' Downloads pre-processed NHANES data files from cloud storage. Data includes
#' all survey cycles (1999-2023) automatically merged and harmonized, with
#' annual updates.
#'
#' @param dataset Character. NHANES dataset base name (e.g., "trigly", "demo").
#'   **Case-insensitive** - use 'demo', 'DEMO', or 'Demo' interchangeably.
#'   Must be a single string (length 1). Leading/trailing whitespace is
#'   automatically trimmed.
#'
#' @details
#' This function downloads NHANES datasets from cloud storage (hosted at
#' nhanes.kylegrealis.com). All datasets combine multiple survey cycles with
#' automatic type harmonization. Data is updated annually via automated
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
#' \donttest{
#' # All case variations work identically:
#' trigly <- read_nhanes("trigly") # Lowercase
#' demo <- read_nhanes("DEMO") # Uppercase
#' acq <- read_nhanes("Acq") # Mixed case
#' }
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
