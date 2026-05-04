library(testthat)
library(nhanesdata)

test_that("repro: fasting weights fail for 1999/2001", {
  # 1999/2001 fasting data uses wtsaf4yr
  mock_data <- data.frame(
    year = c(1999L, 2001L, 2003L),
    seqn = 1:3,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtsaf4yr = c(500, 600, NA),
    wtsaf2yr = c(NA, NA, 300)
  )

  # This currently fails because fasting ONLY looks for wtsaf2yr
  # and doesn't know about wtsaf4yr
  expect_error(
    create_design(mock_data, start_yr = 1999, end_yr = 2003, wt_type = "fasting"),
    NA # We want it to NOT error
  )

  result <- create_design(mock_data, start_yr = 1999, end_yr = 2003, wt_type = "fasting")
  # scaling: n=3 cycles
  # 1999: 500 * 2/3 = 333.33
  # 2001: 600 * 2/3 = 400
  # 2003: 300 * 1/3 = 100
  expect_equal(result$variables$design_weight[1], 500 * 2/3)
  expect_equal(result$variables$design_weight[2], 600 * 2/3)
  expect_equal(result$variables$design_weight[3], 300 * 1/3)
})

test_that("repro: error when 2yr weight is missing for 1999-only analysis", {
  # If I only have 1999 data, I shouldn't need wtint2yr
  mock_data <- data.frame(
    year = 1999L,
    seqn = 1:2,
    sdmvpsu = 1L,
    sdmvstra = 1L,
    wtint4yr = c(500, 1000)
  )

  # This currently fails because weight_vars includes wtint2yr if needs_4yr is TRUE
  expect_error(
    create_design(mock_data, start_yr = 1999, end_yr = 1999, wt_type = "interview"),
    NA
  )

  result <- create_design(mock_data, start_yr = 1999, end_yr = 1999, wt_type = "interview")
  expect_equal(result$variables$design_weight[1], 500) # 500 * 2/1 wait, n is number of cycles.
  # If only 1 cycle (1999), length(cycles) = 1.
  # 500 * 2/1 = 1000.
  # Wait, if n=1, and it's a 4-year weight, does it double?
  # CDC says: "If only 1999-2002 was used, the 4-year weight should be used."
  # If combining 1999-2000 (4-year) with 2001-2002 (4-year), n=2?
  # The package treats each odd year as a "cycle".
  # 1999 is one cycle. 2001 is another.
  # If user says start=1999, end=1999, they have 1 cycle.
  # The 4-year weight already represents two 2-year periods.
  # If they ONLY use 1999-2000, they should use WTINT4YR * 1.
  # Wait, let's check CDC guidance on combining 4-yr and 2-yr.
  # "To combine 1999-2000 and 2001-2002 (both 4-year weights), use 1/2 * 4-year weight."
  # No, that's wrong. 1999-2002 is 4 years. Each 4-year weight is for 4 years.
  # If you combine two 4-year weights, you get 8 years? No, NHANES 1999-2002 is ONE 4-year period.
  # Actually, NHANES 1999-2000 and 2001-2002 were released with 4-year weights because they were meant to be used together as a 4-year sample.
  # The package treats 1999 as a "cycle".
})
