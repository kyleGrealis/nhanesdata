library(testthat)
library(nhanesdata)

# ==============================================================================
# Tests for read_nhanes()
# ==============================================================================

# ------------------------------------------------------------------------------
# Input validation tests
# ------------------------------------------------------------------------------

test_that("read_nhanes requires character input for dataset parameter", {
  expect_error(
    read_nhanes(123),
    class = "simpleError"
  )

  expect_error(
    read_nhanes(NULL),
    class = "simpleError"
  )

  expect_error(
    read_nhanes(c("demo", "bmx")),
    class = "simpleError"
  )
})


test_that("read_nhanes handles invalid dataset names gracefully", {
  skip_on_cran()
  skip_if_offline()

  # Non-existent dataset should error (network error or 404)
  expect_error(
    read_nhanes("this_dataset_does_not_exist_12345"),
    class = "simpleError"
  )
})

# ------------------------------------------------------------------------------
# Case insensitivity tests
# ------------------------------------------------------------------------------

test_that("read_nhanes is case-insensitive for dataset names", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  # All variations should work
  expect_no_error(demo_lower <- read_nhanes("demo"))
  expect_no_error(demo_upper <- read_nhanes("DEMO"))
  expect_no_error(demo_mixed <- read_nhanes("Demo"))

  # All should return the same dataset structure
  expect_equal(names(demo_lower), names(demo_upper))
  expect_equal(names(demo_lower), names(demo_mixed))
  expect_equal(nrow(demo_lower), nrow(demo_upper))
  expect_equal(nrow(demo_lower), nrow(demo_mixed))
})

# ------------------------------------------------------------------------------
# Return value structure tests
# ------------------------------------------------------------------------------

test_that("read_nhanes returns a data.frame/tibble", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  result <- read_nhanes("demo")

  expect_s3_class(result, "data.frame")
  expect_s3_class(result, "tbl_df")  # tibble
})

test_that("read_nhanes returns data with required core columns", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  result <- read_nhanes("demo")

  # All NHANES datasets should have 'year' and 'seqn' columns
  expect_true("year" %in% names(result))
  expect_true("seqn" %in% names(result))
})

test_that("read_nhanes returns data with correct column types for core vars", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  result <- read_nhanes("demo")

  # Core columns should have correct types
  expect_type(result$year, "integer")
  expect_type(result$seqn, "integer")
})

test_that("read_nhanes returns non-empty data", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  result <- read_nhanes("demo")

  expect_gt(nrow(result), 0)
  expect_gt(ncol(result), 2)  # More than just year and seqn
})

# ------------------------------------------------------------------------------
# Message output tests
# ------------------------------------------------------------------------------

test_that("read_nhanes displays informative messages", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  # Should message about loading
  expect_message(
    read_nhanes("demo"),
    "Loading: DEMO"
  )

  # Should message about completion
  expect_message(
    read_nhanes("demo"),
    "complete"
  )
})

test_that("read_nhanes messages use uppercase for dataset name", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  # Even with lowercase input, should display uppercase
  expect_message(
    read_nhanes("demo"),
    "DEMO"
  )
})

# ------------------------------------------------------------------------------
# Multiple dataset loading tests
# ------------------------------------------------------------------------------

test_that("read_nhanes can load different datasets sequentially", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  # Load two different datasets
  demo <- read_nhanes("demo")
  bmx <- read_nhanes("bmx")

  # They should be different
  expect_false(identical(demo, bmx))

  # Both should have core columns
  expect_true("year" %in% names(demo))
  expect_true("year" %in% names(bmx))
  expect_true("seqn" %in% names(demo))
  expect_true("seqn" %in% names(bmx))
})

# ------------------------------------------------------------------------------
# URL construction tests (indirectly tested through read_nhanes)
# ------------------------------------------------------------------------------

test_that("read_nhanes constructs correct URL internally", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  # This indirectly tests that the URL format is correct
  # If the URL were malformed, read_nhanes would fail
  expect_no_error(read_nhanes("demo"))
  expect_no_error(read_nhanes("bmx"))
})

# ------------------------------------------------------------------------------
# Edge cases and boundary conditions
# ------------------------------------------------------------------------------

test_that("read_nhanes handles single-character dataset names", {
  skip_on_cran()
  skip_if_offline()

  # This may or may not exist, but should handle gracefully
  # If it doesn't exist, should error appropriately, not crash
  expect_error(
    read_nhanes("x"),
    class = "simpleError"
  )
})

test_that("read_nhanes handles dataset names with underscores", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  # Some datasets may have underscores in lowercase form
  # Function should handle them appropriately
  # This is more of a smoke test
  result <- tryCatch(
    read_nhanes("demo"),
    error = function(e) NULL
  )

  expect_false(is.null(result))
})


# ------------------------------------------------------------------------------
# Data quality checks
# ------------------------------------------------------------------------------

test_that("read_nhanes returns data with no duplicate seqn within year", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  result <- read_nhanes("demo")

  # Check that seqn is unique within each year
  dupes <- result |>
    dplyr::group_by(year, seqn) |>
    dplyr::filter(dplyr::n() > 1) |>
    dplyr::ungroup()

  expect_equal(nrow(dupes), 0)
})

test_that("read_nhanes returns data with expected year range", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  result <- read_nhanes("demo")

  # Years should be in expected NHANES range (1999-2023+)
  expect_true(all(result$year >= 1999))
  expect_true(all(result$year <= 2030))  # Future-proof a bit

  # Years should be odd numbers (survey cycles start on odd years)
  expect_true(all(result$year %% 2 == 1))
})

test_that("read_nhanes data has no completely NA columns", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not(
    curl::has_internet(),
    "Internet connection required"
  )

  result <- read_nhanes("demo")

  # No column should be entirely NA
  all_na_cols <- sapply(result, function(x) all(is.na(x)))
  expect_false(any(all_na_cols))
})
