library(testthat)
library(nhanesdata)

# ==============================================================================
# Tests for internal utility functions
# ==============================================================================

# NOTE: .get_year_from_suffix() is internal (@noRd), so we access it via :::
# These tests ensure the suffix-to-year mapping is correct, which is critical
# for get_url() and other functions that depend on it.

# ------------------------------------------------------------------------------
# Basic suffix mapping tests
# ------------------------------------------------------------------------------

test_that(".get_year_from_suffix handles empty suffix", {
  # Empty suffix should return 1999 (1999-2000 cycle)
  year <- nhanesdata:::.get_year_from_suffix("")
  expect_equal(year, 1999L)
  expect_type(year, "integer")
})

test_that(".get_year_from_suffix handles suffix A", {
  # A suffix (edge case, some datasets use _A for 1999-2000)
  year <- nhanesdata:::.get_year_from_suffix("A")
  expect_equal(year, 1999L)
  expect_type(year, "integer")
})

test_that(".get_year_from_suffix maps B through J correctly", {
  # Standard NHANES suffixes B-J
  suffixes <- c("B", "C", "D", "E", "F", "G", "H", "I", "J")
  expected_years <- c(
    2001L, 2003L, 2005L, 2007L, 2009L,
    2011L, 2013L, 2015L, 2017L
  )

  for (i in seq_along(suffixes)) {
    year <- nhanesdata:::.get_year_from_suffix(suffixes[i])
    expect_equal(
      year,
      expected_years[i],
      info = sprintf("Suffix %s should map to %d", suffixes[i], expected_years[i])
    )
    expect_type(year, "integer")
  }
})

test_that(".get_year_from_suffix maps L to 2021", {
  # L suffix (2021-2023 cycle, resumed after COVID)
  year <- nhanesdata:::.get_year_from_suffix("L")
  expect_equal(year, 2021L)
  expect_type(year, "integer")
})

test_that(".get_year_from_suffix handles special suffixes S and U", {
  # S and U both map to 2017 (special datasets from 2017-2018)
  year_s <- nhanesdata:::.get_year_from_suffix("S")
  year_u <- nhanesdata:::.get_year_from_suffix("U")

  expect_equal(year_s, 2017L)
  expect_equal(year_u, 2017L)
  expect_type(year_s, "integer")
  expect_type(year_u, "integer")
})

# ------------------------------------------------------------------------------
# Invalid suffix handling tests
# ------------------------------------------------------------------------------

test_that(".get_year_from_suffix returns NULL for unrecognized suffixes", {
  # K is intentionally skipped (2019-2020 had data collection issues)
  year_k <- nhanesdata:::.get_year_from_suffix("K")
  expect_null(year_k)

  # Other invalid suffixes
  year_m <- nhanesdata:::.get_year_from_suffix("M")
  expect_null(year_m)

  year_z <- nhanesdata:::.get_year_from_suffix("Z")
  expect_null(year_z)
})

test_that(".get_year_from_suffix returns NULL for lowercase suffixes", {
  # Function expects uppercase input (caller should normalize)
  year_lower <- nhanesdata:::.get_year_from_suffix("j")
  expect_null(year_lower)
})

test_that(".get_year_from_suffix returns NULL for multi-character input", {
  # Should only handle single characters
  year_multi <- nhanesdata:::.get_year_from_suffix("AB")
  expect_null(year_multi)
})

test_that(".get_year_from_suffix returns NULL for numeric input", {
  # Should only handle character suffixes
  year_num <- nhanesdata:::.get_year_from_suffix("1")
  expect_null(year_num)

  year_num2 <- nhanesdata:::.get_year_from_suffix("9")
  expect_null(year_num2)
})

test_that(".get_year_from_suffix returns NULL for special characters", {
  year_special <- nhanesdata:::.get_year_from_suffix("_")
  expect_null(year_special)

  year_special2 <- nhanesdata:::.get_year_from_suffix("-")
  expect_null(year_special2)
})

# ------------------------------------------------------------------------------
# Year progression tests
# ------------------------------------------------------------------------------

test_that(".get_year_from_suffix years are in chronological order", {
  # Suffixes should map to sequential odd years (2-year cycles)
  suffixes <- c("A", "B", "C", "D", "E", "F", "G", "H", "I", "J")
  years <- sapply(suffixes, nhanesdata:::.get_year_from_suffix)

  # Should be strictly increasing (except A=B both 1999 in some edge cases)
  diffs <- diff(years)
  expect_true(all(diffs >= 0))

  # Most differences should be 2 (biennial cycles)
  expect_true(all(diffs == 0 | diffs == 2))
})

test_that(".get_year_from_suffix all years are odd numbers", {
  # NHANES cycles start on odd years
  suffixes <- c("", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "L", "S", "U")
  years <- sapply(suffixes, nhanesdata:::.get_year_from_suffix)

  # Remove NULLs and convert to numeric
  years <- unlist(years[!sapply(years, is.null)])

  expect_true(all(years %% 2 == 1))
})

test_that(".get_year_from_suffix all years are in expected range", {
  suffixes <- c("", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "L", "S", "U")
  years <- sapply(suffixes, nhanesdata:::.get_year_from_suffix)

  # Remove NULLs and convert to numeric
  years <- unlist(years[!sapply(years, is.null)])

  # Should be between 1999 and 2023
  expect_true(all(years >= 1999))
  expect_true(all(years <= 2023))
})

# ------------------------------------------------------------------------------
# Comprehensive mapping table tests
# ------------------------------------------------------------------------------

test_that(".get_year_from_suffix has complete mapping for all valid suffixes", {
  # All valid NHANES suffixes (excluding K)
  valid_suffixes <- c("", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "L", "S", "U")

  for (suffix in valid_suffixes) {
    year <- nhanesdata:::.get_year_from_suffix(suffix)
    expect_false(
      is.null(year),
      info = sprintf("Suffix '%s' should have a valid year mapping", suffix)
    )
    expect_type(year, "integer")
  }
})

test_that(".get_year_from_suffix returns integer type for all valid suffixes", {
  valid_suffixes <- c("", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "L", "S", "U")

  for (suffix in valid_suffixes) {
    year <- nhanesdata:::.get_year_from_suffix(suffix)
    expect_type(year, "integer")
  }
})

# ------------------------------------------------------------------------------
# Edge cases and boundary conditions
# ------------------------------------------------------------------------------

test_that(".get_year_from_suffix handles whitespace", {
  # Whitespace should not be recognized
  year_space <- nhanesdata:::.get_year_from_suffix(" ")
  expect_null(year_space)

  year_tab <- nhanesdata:::.get_year_from_suffix("\t")
  expect_null(year_tab)
})

test_that(".get_year_from_suffix is case-sensitive", {
  # Lowercase should return NULL (caller must normalize to uppercase)
  expect_null(nhanesdata:::.get_year_from_suffix("a"))
  expect_null(nhanesdata:::.get_year_from_suffix("b"))
  expect_null(nhanesdata:::.get_year_from_suffix("j"))
  expect_null(nhanesdata:::.get_year_from_suffix("l"))
})

# ------------------------------------------------------------------------------
# Specific suffix verification tests
# ------------------------------------------------------------------------------

test_that(".get_year_from_suffix B suffix is 2001", {
  # First standard cycle after initial 1999-2000
  expect_equal(nhanesdata:::.get_year_from_suffix("B"), 2001L)
})

test_that(".get_year_from_suffix J suffix is 2017", {
  # Most recent standard cycle before COVID interruption
  expect_equal(nhanesdata:::.get_year_from_suffix("J"), 2017L)
})

test_that(".get_year_from_suffix K suffix is not mapped", {
  # K is intentionally skipped due to COVID-19 data collection issues
  expect_null(nhanesdata:::.get_year_from_suffix("K"))
})

test_that(".get_year_from_suffix L suffix is 2021", {
  # First cycle after COVID interruption
  expect_equal(nhanesdata:::.get_year_from_suffix("L"), 2021L)
})

# ------------------------------------------------------------------------------
# Consistency with get_url() behavior
# ------------------------------------------------------------------------------

test_that(".get_year_from_suffix supports all suffixes used in get_url", {
  # get_url should be able to handle all these suffixes
  suffixes_in_use <- c("", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "L")

  for (suffix in suffixes_in_use) {
    year <- nhanesdata:::.get_year_from_suffix(suffix)
    expect_false(is.null(year))
    expect_type(year, "integer")
  }
})

# ------------------------------------------------------------------------------
# Regression tests
# ------------------------------------------------------------------------------

test_that(".get_year_from_suffix maintains backward compatibility", {
  # These mappings should never change to maintain compatibility
  # Use separate vectors because list('' = value) causes a parse error
  # (R treats empty-string names as zero-length variable names)
  critical_suffixes <- c("", "B", "D", "F", "H", "J", "L")
  critical_years <- c(1999L, 2001L, 2005L, 2009L, 2013L, 2017L, 2021L)

  for (i in seq_along(critical_suffixes)) {
    year <- nhanesdata:::.get_year_from_suffix(critical_suffixes[i])
    expect_equal(
      year,
      critical_years[i],
      info = sprintf(
        "Critical mapping changed: '%s' should always map to %d",
        critical_suffixes[i], critical_years[i]
      )
    )
  }
})
