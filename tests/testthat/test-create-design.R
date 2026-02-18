library(testthat)
library(nhanesdata)

# ==============================================================================
# Tests for create_design()
#
# These tests verify that create_design() properly calculates survey weights
# according to CDC guidelines and creates valid survey design objects.
# ==============================================================================

# ==============================================================================
# Input validation tests
# ==============================================================================

test_that("start_yr and end_yr must be numeric", {
  mock_data <- data.frame(
    year = 1999L,
    seqn = 1L,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtint2yr = 1000
  )

  expect_error(
    create_design(mock_data, start_yr = "1999", end_yr = 2001, wt_type = "interview"),
    "must be numeric"
  )

  expect_error(
    create_design(mock_data, start_yr = 1999, end_yr = "2001", wt_type = "interview"),
    "must be numeric"
  )
})

test_that("start_yr must be a valid odd-year NHANES cycle", {
  mock_data <- data.frame(
    year = 1999L,
    seqn = 1L,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtint2yr = 1000
  )

  expect_error(
    create_design(mock_data, start_yr = 2000, end_yr = 2001, wt_type = "interview"),
    "must be a valid NHANES cycle start year"
  )

  expect_error(
    create_design(mock_data, start_yr = 1998, end_yr = 2001, wt_type = "interview"),
    "must be a valid NHANES cycle start year"
  )
})

test_that("end_yr must be a valid odd-year NHANES cycle", {
  mock_data <- data.frame(
    year = 1999L,
    seqn = 1L,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtint2yr = 1000
  )

  expect_error(
    create_design(mock_data, start_yr = 1999, end_yr = 2000, wt_type = "interview"),
    "must be a valid NHANES cycle start year"
  )
})

test_that("end_yr must be >= start_yr", {
  mock_data <- data.frame(
    year = 1999L,
    seqn = 1L,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtint2yr = 1000
  )

  expect_error(
    create_design(mock_data, start_yr = 2001, end_yr = 1999, wt_type = "interview"),
    "end_yr must be >= start_yr"
  )
})

test_that("wt_type must be valid", {
  mock_data <- data.frame(
    year = 1999L,
    seqn = 1L,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtint2yr = 1000
  )

  expect_error(
    create_design(mock_data, start_yr = 1999, end_yr = 2001, wt_type = "invalid"),
    "Invalid weight type"
  )
})

test_that("dataset must contain year column", {
  mock_data <- data.frame(
    seqn = 1L,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtint2yr = 1000
  )

  expect_error(
    create_design(mock_data, start_yr = 1999, end_yr = 2001, wt_type = "interview"),
    "must contain a 'year' column"
  )
})

test_that("no data in year range produces error", {
  mock_data <- data.frame(
    year = 1999L,
    seqn = 1L,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtint2yr = 1000
  )

  expect_error(
    create_design(mock_data, start_yr = 2011, end_yr = 2013, wt_type = "interview"),
    "No data found for years"
  )
})

test_that("data with invalid cycle years produces error", {
  mock_data <- data.frame(
    year = c(1999L, 2000L), # 2000 is not a valid cycle start year
    seqn = 1:2,
    sdmvpsu = c(1L, 1L),
    sdmvstra = c(1L, 1L),
    wtint2yr = c(1000, 1000)
  )

  expect_error(
    create_design(mock_data, start_yr = 1999, end_yr = 2001, wt_type = "interview"),
    "invalid NHANES cycle years"
  )
})

test_that("missing required variables produces error", {
  mock_data <- data.frame(
    year = 1999L,
    seqn = 1L,
    wtint2yr = 1000
  )

  expect_error(
    create_design(mock_data, start_yr = 1999, end_yr = 2001, wt_type = "interview"),
    "Missing required variables: sdmvpsu, sdmvstra"
  )
})

test_that("missing weight variables produces error", {
  # For 1999 cycles, need both 2yr and 4yr weights
  mock_data <- data.frame(
    year = 1999L,
    seqn = 1L,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtint2yr = 1000
  )

  expect_error(
    create_design(mock_data, start_yr = 1999, end_yr = 2001, wt_type = "interview"),
    "Missing required variables: wtint4yr"
  )
})


# ==============================================================================
# Weight calculation tests
# ==============================================================================

test_that("interview weights calculated correctly for 1999/2001 cycles", {
  mock_data <- data.frame(
    year = c(1999L, 1999L, 2001L, 2001L),
    seqn = 1:4,
    sdmvpsu = c(1L, 2L, 1L, 2L),
    sdmvstra = c(1L, 1L, 2L, 2L),
    wtint2yr = c(1000, 2000, 1500, 2500),
    wtint4yr = c(500, 1000, 750, 1250)
  )

  result <- create_design(
    mock_data,
    start_yr = 1999,
    end_yr = 2001,
    wt_type = "interview"
  )

  # Should use 4yr weight * 2/2 = 4yr weight * 1
  expect_equal(result$variables$design_weight[1], 500)
  expect_equal(result$variables$design_weight[2], 1000)
  expect_equal(result$variables$design_weight[3], 750)
  expect_equal(result$variables$design_weight[4], 1250)
})

test_that("interview weights calculated correctly for 2003+ cycles", {
  mock_data <- data.frame(
    year = c(2003L, 2003L, 2005L, 2005L),
    seqn = 1:4,
    sdmvpsu = c(1L, 2L, 1L, 2L),
    sdmvstra = c(1L, 1L, 2L, 2L),
    wtint2yr = c(1000, 2000, 1500, 2500)
  )

  result <- create_design(
    mock_data,
    start_yr = 2003,
    end_yr = 2005,
    wt_type = "interview"
  )

  # Should use 2yr weight * 1/2 = 2yr weight * 0.5
  expect_equal(result$variables$design_weight[1], 500)
  expect_equal(result$variables$design_weight[2], 1000)
  expect_equal(result$variables$design_weight[3], 750)
  expect_equal(result$variables$design_weight[4], 1250)
})

test_that("mixed cycles use correct weight formulas", {
  # 4 cycles: 1999, 2001, 2003, 2005
  mock_data <- data.frame(
    year = c(1999L, 2001L, 2003L, 2005L),
    seqn = 1:4,
    sdmvpsu = c(1L, 1L, 1L, 1L),
    sdmvstra = c(1L, 1L, 1L, 1L),
    wtint2yr = c(1000, 1000, 1000, 1000),
    wtint4yr = c(800, 800, NA, NA),
    wtmec2yr = c(900, 900, 900, 900),
    wtmec4yr = c(720, 720, NA, NA)
  )

  result <- create_design(
    mock_data,
    start_yr = 1999,
    end_yr = 2005,
    wt_type = "mec"
  )

  # 1999 & 2001: 4yr weight * 2/4 = 4yr weight * 0.5
  # 2003 & 2005: 2yr weight * 1/4 = 2yr weight * 0.25
  expect_equal(result$variables$design_weight[1], 720 * 0.5) # 360
  expect_equal(result$variables$design_weight[2], 720 * 0.5) # 360
  expect_equal(result$variables$design_weight[3], 900 * 0.25) # 225
  expect_equal(result$variables$design_weight[4], 900 * 0.25) # 225
})

test_that("fasting weights use only 2yr weights", {
  mock_data <- data.frame(
    year = c(2003L, 2005L),
    seqn = 1:2,
    sdmvpsu = c(1L, 1L),
    sdmvstra = c(1L, 1L),
    wtsaf2yr = c(500, 600)
  )

  result <- create_design(
    mock_data,
    start_yr = 2003,
    end_yr = 2005,
    wt_type = "fasting"
  )

  # Should use 2yr fasting weight * 1/2
  expect_equal(result$variables$design_weight[1], 250)
  expect_equal(result$variables$design_weight[2], 300)
})

test_that("single cycle weight calculation", {
  mock_data <- data.frame(
    year = 2003L,
    seqn = 1:3,
    sdmvpsu = c(1L, 2L, 1L),
    sdmvstra = c(1L, 1L, 2L),
    wtint2yr = c(1000, 2000, 3000)
  )

  result <- create_design(
    mock_data,
    start_yr = 2003,
    end_yr = 2003,
    wt_type = "interview"
  )

  # Single cycle: 2yr weight * 1/1 = 2yr weight
  expect_equal(result$variables$design_weight[1], 1000)
  expect_equal(result$variables$design_weight[2], 2000)
  expect_equal(result$variables$design_weight[3], 3000)
})


# ==============================================================================
# Survey design object tests
# ==============================================================================

test_that("create_design returns tbl_svy object", {
  mock_data <- data.frame(
    year = 2003L,
    seqn = 1:3,
    sdmvpsu = c(1L, 2L, 1L),
    sdmvstra = c(1L, 1L, 2L),
    wtint2yr = c(1000, 2000, 3000)
  )

  result <- create_design(
    mock_data,
    start_yr = 2003,
    end_yr = 2003,
    wt_type = "interview"
  )

  expect_s3_class(result, "tbl_svy")
  expect_s3_class(result, "survey.design2")
})

test_that("design object contains design_weight column", {
  mock_data <- data.frame(
    year = 2003L,
    seqn = 1:3,
    sdmvpsu = c(1L, 2L, 1L),
    sdmvstra = c(1L, 1L, 2L),
    wtint2yr = c(1000, 2000, 3000)
  )

  result <- create_design(
    mock_data,
    start_yr = 2003,
    end_yr = 2003,
    wt_type = "interview"
  )

  expect_true("design_weight" %in% names(result$variables))
})

test_that("design object preserves original data columns", {
  mock_data <- data.frame(
    year = 2003L,
    seqn = 1:3,
    custom_var = c("A", "B", "C"),
    sdmvpsu = c(1L, 2L, 1L),
    sdmvstra = c(1L, 1L, 2L),
    wtint2yr = c(1000, 2000, 3000)
  )

  result <- create_design(
    mock_data,
    start_yr = 2003,
    end_yr = 2003,
    wt_type = "interview"
  )

  expect_true("custom_var" %in% names(result$variables))
  expect_equal(result$variables$custom_var, c("A", "B", "C"))
})


# ==============================================================================
# Zero/NA weight handling tests
# ==============================================================================

test_that("zero weights produce informative message", {
  mock_data <- data.frame(
    year = 2003L,
    seqn = 1:3,
    sdmvpsu = c(1L, 2L, 1L),
    sdmvstra = c(1L, 1L, 2L),
    wtint2yr = c(1000, 0, 3000)
  )

  expect_message(
    result <- create_design(
      mock_data,
      start_yr = 2003,
      end_yr = 2003,
      wt_type = "interview"
    ),
    "zero.*weights"
  )
})

test_that("NA weights produce informative message and are filtered out", {
  mock_data <- data.frame(
    year = 2003L,
    seqn = 1:3,
    sdmvpsu = c(1L, 2L, 1L),
    sdmvstra = c(1L, 1L, 2L),
    wtint2yr = c(1000, NA, 3000)
  )

  expect_message(
    result <- create_design(
      mock_data,
      start_yr = 2003,
      end_yr = 2003,
      wt_type = "interview"
    ),
    "Filtered out.*without valid.*weights"
  )

  # Only 2 participants should remain (the ones with valid weights)
  expect_equal(nrow(result$variables), 2)
  expect_equal(result$variables$seqn, c(1, 3))
})

test_that("zero weights are retained but NA weights are filtered out", {
  # Test that NA weights are automatically filtered out
  mock_data_with_na <- data.frame(
    year = 2003L,
    seqn = 1:4,
    sdmvpsu = c(1L, 2L, 1L, 2L),
    sdmvstra = c(1L, 1L, 2L, 2L),
    wtint2yr = c(1000, 0, NA, 3000)
  )

  result <- suppressMessages(
    create_design(
      mock_data_with_na,
      start_yr = 2003,
      end_yr = 2003,
      wt_type = "interview"
    )
  )

  # Only 3 participants should remain (NA filtered out, zero retained)
  expect_equal(nrow(result$variables), 3)
  expect_equal(result$variables$seqn, c(1, 2, 4))
  expect_equal(result$variables$design_weight[2], 0) # Zero weight retained

  # Test that zero weights work and are retained
  mock_data_zero_only <- data.frame(
    year = 2003L,
    seqn = 1:3,
    sdmvpsu = c(1L, 2L, 1L),
    sdmvstra = c(1L, 1L, 2L),
    wtint2yr = c(1000, 0, 3000)
  )

  result <- suppressMessages(
    create_design(
      mock_data_zero_only,
      start_yr = 2003,
      end_yr = 2003,
      wt_type = "interview"
    )
  )

  expect_equal(nrow(result$variables), 3)
  expect_equal(result$variables$design_weight[2], 0)
})


# ==============================================================================
# Edge cases
# ==============================================================================

test_that("cycles with gaps are handled correctly", {
  # Skip 2005, include 2003 and 2007
  mock_data <- data.frame(
    year = c(2003L, 2007L),
    seqn = 1:2,
    sdmvpsu = c(1L, 1L),
    sdmvstra = c(1L, 1L),
    wtint2yr = c(1000, 2000)
  )

  result <- create_design(
    mock_data,
    start_yr = 2003,
    end_yr = 2007,
    wt_type = "interview"
  )

  # Weight should be divided by number of cycles PRESENT (2, not 3)
  expect_equal(result$variables$design_weight[1], 500) # 1000 * 1/2
  expect_equal(result$variables$design_weight[2], 1000) # 2000 * 1/2
})

test_that("wt_type accepts abbreviations", {
  mock_data <- data.frame(
    year = 2003L,
    seqn = 1L,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtint2yr = 1000
  )

  expect_no_error(
    create_design(mock_data, start_yr = 2003, end_yr = 2003, wt_type = "int")
  )
})

test_that("function sets survey.lonely.psu option", {
  mock_data <- data.frame(
    year = 2003L,
    seqn = 1L,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtint2yr = 1000
  )

  create_design(mock_data, start_yr = 2003, end_yr = 2003, wt_type = "interview")

  expect_equal(getOption("survey.lonely.psu"), "adjust")
})
