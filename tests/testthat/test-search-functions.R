library(testthat)
library(nhanesdata)

# ==============================================================================
# term_search() Tests
# ==============================================================================
#
# term_search() is a thin wrapper around nhanesA::nhanesSearch() that adds:
# - Input validation
# - Case-insensitive search (via ignore.case = TRUE)
# - Column selection (first 3 + Begin.Year)
# - Type conversion (Begin.Year to numeric)
# - Sorting (desc by year, then by variable name)
#
# We test ONLY our wrapper logic, not nhanesA's search functionality.
# ==============================================================================

# ------------------------------------------------------------------------------
# Input validation tests
# ------------------------------------------------------------------------------

test_that("term_search rejects NULL input", {
  expect_error(
    term_search(NULL),
    "must be a single character string",
    fixed = FALSE
  )
})

test_that("term_search rejects empty string", {
  expect_error(
    term_search(""),
    "'var' must be a non-empty string",
    fixed = TRUE
  )
})

test_that("term_search rejects non-character input", {
  expect_error(
    term_search(123),
    "must be a single character string",
    fixed = FALSE
  )
})

test_that("term_search rejects multiple strings", {
  expect_error(
    term_search(c("diabetes", "glucose")),
    "must be a single character string",
    fixed = FALSE
  )
})

test_that("term_search rejects missing argument", {
  expect_error(
    term_search(),
    "Argument 'var' is required",
    fixed = TRUE
  )
})

# ------------------------------------------------------------------------------
# Return structure tests (test OUR transformations)
# ------------------------------------------------------------------------------

test_that("term_search returns a data.frame", {
  skip_on_cran()

  result <- term_search("diabetes")
  expect_s3_class(result, "data.frame")
})

test_that("term_search selects exactly 4 columns", {
  skip_on_cran()

  result <- term_search("glucose")

  # WE select 4 specific columns - test that
  expect_equal(ncol(result), 4)
})

test_that("term_search returns columns in correct order", {
  skip_on_cran()

  result <- term_search("age")

  # WE specify column order - test that
  expect_named(
    result,
    c("Variable.Name", "Variable.Description", "Data.File.Name", "Begin.Year")
  )
})

test_that("term_search converts Begin.Year to numeric", {
  skip_on_cran()

  result <- term_search("weight")

  # WE do type conversion - test that
  expect_type(result$Begin.Year, "double")
})

test_that("term_search sorts by Begin.Year descending", {
  skip_on_cran()

  result <- term_search("cholesterol")

  # WE add sorting - test that
  if (nrow(result) > 1) {
    expect_true(all(diff(result$Begin.Year) <= 0))
  }
})

test_that("term_search sorts by Variable.Name within year groups", {
  skip_on_cran()

  result <- term_search("bmi")

  # WE sort by variable name within year - test that
  if (nrow(result) > 1) {
    # Check each year group is alphabetically sorted
    years <- unique(result$Begin.Year)
    for (yr in years) {
      year_subset <- result[result$Begin.Year == yr, ]
      if (nrow(year_subset) > 1) {
        expect_true(
          all(year_subset$Variable.Name == sort(year_subset$Variable.Name)),
          label = sprintf("Year %s not sorted", yr)
        )
      }
    }
  }
})

# ------------------------------------------------------------------------------
# Error handling tests (test OUR error handling)
# ------------------------------------------------------------------------------

test_that("term_search returns empty data.frame structure on API failure", {
  # We can't easily mock API failures, but we can verify the structure
  # that would be returned matches what we expect
  skip("Manual test - requires mocking nhanesA")

  # If this test is enabled in future with mocking:
  # - Mock nhanesA::nhanesSearch to throw error
  # - Verify we get data.frame with 4 columns, 0 rows
  # - Verify column names match expected
  # - Verify Begin.Year is numeric type
})

test_that("term_search handles no-match results gracefully", {
  skip_on_cran()

  # A nonsense search term
  result <- term_search("zzzzqqqq12345xxxxx")

  # WE ensure it returns a data.frame even when nhanesA returns NULL
  expect_s3_class(result, "data.frame")
  expect_equal(ncol(result), 4)
  expect_named(
    result,
    c("Variable.Name", "Variable.Description", "Data.File.Name", "Begin.Year")
  )
})


# ==============================================================================
# var_search() Tests
# ==============================================================================
#
# var_search() is a thin wrapper around nhanesA::nhanesSearchVarName() that adds:
# - Input validation
# - Automatic uppercase conversion
# - Error handling
#
# NOTE: nhanesA::nhanesSearchVarName() returns a CHARACTER VECTOR of table names,
# not a data.frame. We pass this through as-is (only error cases return data.frame).
#
# We test ONLY our wrapper logic, not nhanesA's search functionality.
# ==============================================================================

# ------------------------------------------------------------------------------
# Input validation tests
# ------------------------------------------------------------------------------

test_that("var_search rejects NULL input", {
  expect_error(
    var_search(NULL),
    "must be a single character string",
    fixed = FALSE
  )
})

test_that("var_search rejects empty string", {
  expect_error(
    var_search(""),
    "'var' must be a non-empty string",
    fixed = TRUE
  )
})

test_that("var_search rejects non-character input", {
  expect_error(
    var_search(123),
    "must be a single character string",
    fixed = FALSE
  )
})

test_that("var_search rejects multiple strings", {
  expect_error(
    var_search(c("SEQN", "RIAGENDR")),
    "must be a single character string",
    fixed = FALSE
  )
})

test_that("var_search rejects missing argument", {
  expect_error(
    var_search(),
    "Argument 'var' is required",
    fixed = TRUE
  )
})

# ------------------------------------------------------------------------------
# Case conversion tests (test OUR transformation)
# ------------------------------------------------------------------------------

test_that("var_search converts lowercase to uppercase", {
  skip_on_cran()

  # WE do str_to_upper() - test that it works
  result_lower <- var_search("seqn")
  result_upper <- var_search("SEQN")

  # Both should return same result (testing our conversion works)
  expect_equal(class(result_lower), class(result_upper))
  expect_equal(length(result_lower), length(result_upper))
  expect_equal(result_lower, result_upper)
})

test_that("var_search converts mixed case to uppercase", {
  skip_on_cran()

  # WE do str_to_upper() - test that it works with mixed case
  result_mixed <- var_search("RidAgeYr")
  result_upper <- var_search("RIDAGEYR")

  # Both should return same result
  expect_equal(class(result_mixed), class(result_upper))
  expect_equal(result_mixed, result_upper)
})

# ------------------------------------------------------------------------------
# Return structure tests
# ------------------------------------------------------------------------------

test_that("var_search returns a character vector for valid variable", {
  skip_on_cran()

  result <- var_search("RIAGENDR")

  # WE pass through nhanesA's character vector result
  expect_type(result, "character")
  expect_true(length(result) > 0)
})

test_that("var_search returns data.frame on no-match", {
  skip_on_cran()

  # A nonsense variable name
  result <- var_search("NOTAREALVAR12345")

  # WE ensure it returns a data.frame when nhanesA returns NULL
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

# ------------------------------------------------------------------------------
# Error handling tests
# ------------------------------------------------------------------------------

test_that("var_search returns empty data.frame structure on API failure", {
  # We can't easily mock API failures, but we can verify the structure
  # that would be returned matches what we expect
  skip("Manual test - requires mocking nhanesA")

  # If this test is enabled in future with mocking:
  # - Mock nhanesA::nhanesSearchVarName to throw error
  # - Verify we get data.frame with correct columns, 0 rows
  # - Verify column types match expected
})
