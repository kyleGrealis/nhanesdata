# tests/testthat/setup.R

# Helper function to skip tests when offline or when NHANES API is unavailable
skip_if_offline <- function() {
  # Check general internet connectivity
  has_internet <- tryCatch(
    {
      con <- url("https://www.google.com", open = "rb")
      close(con)
      TRUE
    },
    error = function(e) FALSE,
    warning = function(w) FALSE
  )

  if (!has_internet) {
    testthat::skip("No internet connection")
  }

  # Check if NHANES API is specifically reachable
  # Use a simple search that should always return results
  nhanes_available <- tryCatch(
    {
      result <- nhanesA::nhanesSearch("SEQN", ignore.case = TRUE)
      !is.null(result) && is.data.frame(result) && nrow(result) > 0
    },
    error = function(e) FALSE,
    warning = function(w) FALSE
  )

  if (!nhanes_available) {
    testthat::skip("NHANES API unavailable")
  }
}
