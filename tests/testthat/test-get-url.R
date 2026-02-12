library(testthat)
library(nhanesdata)

# ==============================================================================
# Tests for get_url()
# ==============================================================================

# ------------------------------------------------------------------------------
# Input validation and normalization tests
# ------------------------------------------------------------------------------

test_that("get_url accepts character input", {
  expect_no_error(get_url("DEMO_J"))
  expect_no_error(get_url("demo"))
})

test_that("get_url normalizes input to uppercase", {
  # Should work with any case
  url_lower <- get_url("demo_j")
  url_upper <- get_url("DEMO_J")
  url_mixed <- get_url("Demo_J")

  # All should return the same URL
  expect_equal(url_lower, url_upper)
  expect_equal(url_lower, url_mixed)
})

test_that("get_url handles tables without suffixes", {
  url <- get_url("DEMO")

  # Should construct 1999-2000 cycle URL
  expect_true(grepl("1999", url))
  expect_true(grepl("DEMO", url))
})

test_that("get_url handles tables with suffixes", {
  url_j <- get_url("DEMO_J")

  # J suffix = 2017-2018 cycle
  expect_true(grepl("2017", url_j))
  expect_true(grepl("DEMO_J", url_j))
})

test_that("get_url handles single letter suffixes correctly", {
  # Test various suffix letters
  url_b <- get_url("DEMO_B")
  url_c <- get_url("DEMO_C")
  url_l <- get_url("DEMO_L")

  expect_true(grepl("2001", url_b)) # B = 2001-2002 # nolint
  expect_true(grepl("2003", url_c)) # C = 2003-2004 # nolint
  expect_true(grepl("2021", url_l)) # L = 2021-2023 # nolint
})

# ------------------------------------------------------------------------------
# URL format and structure tests
# ------------------------------------------------------------------------------

test_that("get_url returns proper CDC URL format", {
  url <- get_url("DEMO_J")

  # Should be a CDC NHANES URL
  expect_true(grepl("^https://wwwn\\.cdc\\.gov/nchs/data/nhanes/public/", url))
  expect_true(grepl("\\.htm$", url))
})

test_that("get_url constructs URLs with correct structure", {
  url <- get_url("DEMO_J")

  # URL should follow pattern:
  # https://wwwn.cdc.gov/nchs/data/nhanes/public/YEAR/datafiles/TABLE.htm
  pattern <- paste0(
    "^https://wwwn\\.cdc\\.gov/nchs/data/",
    "nhanes/public/\\d{4}/datafiles/[A-Z_]+\\.htm$"
  )
  expect_true(grepl(pattern, url))
})

test_that("get_url includes table name in URL", {
  url_demo <- get_url("DEMO_J")
  url_bmx <- get_url("BMX_J")
  url_diq <- get_url("DIQ_J")

  expect_true(grepl("DEMO_J", url_demo))
  expect_true(grepl("BMX_J", url_bmx))
  expect_true(grepl("DIQ_J", url_diq))
})

# ------------------------------------------------------------------------------
# Suffix to year mapping tests
# ------------------------------------------------------------------------------

test_that("get_url maps suffix A to 1999", {
  url <- get_url("DEMO_A")
  expect_true(grepl("1999", url))
})

test_that("get_url maps suffix B through J correctly", {
  # Test a sampling of suffixes
  suffixes <- c("B", "C", "D", "E", "F", "G", "H", "I", "J")
  expected_years <- c(2001, 2003, 2005, 2007, 2009, 2011, 2013, 2015, 2017)

  for (i in seq_along(suffixes)) {
    url <- get_url(paste0("DEMO_", suffixes[i]))
    expect_true(
      grepl(as.character(expected_years[i]), url),
      info = sprintf("Suffix %s should map to year %d", suffixes[i], expected_years[i])
    )
  }
})

test_that("get_url maps suffix L to 2021", {
  url <- get_url("DEMO_L")
  expect_true(grepl("2021", url))
})

test_that("get_url handles special suffixes S and U", {
  # S and U both map to 2017 (special datasets from 2017-2018)
  url_s <- get_url("DEMO_S")
  url_u <- get_url("DEMO_U")

  expect_true(grepl("2017", url_s))
  expect_true(grepl("2017", url_u))
})

test_that("get_url warns about unrecognized suffixes", {
  # K is intentionally skipped (2019-2020 had data collection issues)
  expect_warning(
    get_url("DEMO_K"),
    "Unrecognized table suffix"
  )

  # Other invalid suffixes
  expect_warning(
    get_url("DEMO_Z"),
    "Unrecognized table suffix"
  )
})

test_that("get_url defaults to 1999 for unrecognized suffixes", {
  # Should warn but still return a URL
  url <- suppressWarnings(get_url("DEMO_K"))
  expect_true(grepl("1999", url))

  url_z <- suppressWarnings(get_url("DEMO_Z"))
  expect_true(grepl("1999", url_z))
})

# ------------------------------------------------------------------------------
# Return value and message behavior tests
# ------------------------------------------------------------------------------

test_that("get_url returns URL invisibly", {
  # The function should return invisibly
  expect_invisible(get_url("DEMO_J"))
})

test_that("get_url returns a character string", {
  url <- get_url("DEMO_J")
  expect_type(url, "character")
  expect_length(url, 1)
})

test_that("get_url messages the URL", {
  expect_message(
    get_url("DEMO_J"),
    "https://wwwn\\.cdc\\.gov/nchs/data/nhanes/public"
  )
})

test_that("get_url message contains the full URL", {
  # Capture the message
  expect_message(
    url <- get_url("DEMO_J"),
    "2017.*DEMO_J"
  )
})

# ------------------------------------------------------------------------------
# Edge cases and special inputs
# ------------------------------------------------------------------------------

test_that("get_url handles lowercase table names", {
  url <- get_url("demo_j")

  # Should normalize to uppercase
  expect_true(grepl("DEMO_J", url))
  expect_true(grepl("2017", url))
})

test_that("get_url handles mixed case table names", {
  url <- get_url("DeMo_j")

  # Should normalize to uppercase
  expect_true(grepl("DEMO_J", url))
})

test_that("get_url handles table names with no underscore", {
  url <- get_url("DEMO")

  # Should construct URL for 1999-2000 cycle
  expect_true(grepl("1999", url))
  expect_true(grepl("DEMO", url))
  expect_false(grepl("DEMO_", url)) # Should not have underscore
})

test_that("get_url handles table names with multiple underscores", {
  # Some table names might have underscores in the base name
  url <- get_url("DR1TOT_J")

  expect_true(grepl("DR1TOT_J", url))
  expect_true(grepl("2017", url))
})

test_that("get_url extracts only final letter as suffix", {
  # If table has underscore in name, should only use final letter
  url <- get_url("DR1_IFF_J")

  # J should be recognized as suffix, not IFF_J
  expect_true(grepl("2017", url))
  expect_true(grepl("DR1_IFF_J", url))
})

# ------------------------------------------------------------------------------
# Common NHANES table examples
# ------------------------------------------------------------------------------

test_that("get_url works with common NHANES tables", {
  # Test several real NHANES table names
  common_tables <- c(
    "DEMO_J", # Demographics
    "BMX_J", # Body measures
    "BPX_J", # Blood pressure
    "DIQ_J", # Diabetes
    "GHB_J", # Glycohemoglobin
    "TCHOL_J" # Cholesterol
  )

  for (table in common_tables) {
    url <- get_url(table)
    expect_true(grepl("2017", url))
    expect_true(grepl(table, url))
    expect_true(grepl("^https://", url))
  }
})

test_that("get_url works with tables from different cycles", {
  # Same table, different cycles
  url_1999 <- get_url("DEMO")
  url_2001 <- get_url("DEMO_B")
  url_2017 <- get_url("DEMO_J")
  url_2021 <- get_url("DEMO_L")

  expect_true(grepl("1999", url_1999))
  expect_true(grepl("2001", url_2001))
  expect_true(grepl("2017", url_2017))
  expect_true(grepl("2021", url_2021))

  # All should have DEMO in them
  expect_true(all(grepl("DEMO", c(url_1999, url_2001, url_2017, url_2021))))
})

# ------------------------------------------------------------------------------
# Integration with documentation
# ------------------------------------------------------------------------------

test_that("get_url generates valid URLs (structure check)", {
  url <- get_url("DEMO_J")

  # URL should be valid structure (we can't test if it resolves without network)
  # But we can check format
  expect_match(url, "^https://")
  expect_match(url, "\\.htm$")
  expect_true(nchar(url) > 50) # Should be a reasonably long URL
})

test_that("get_url includes datafiles in path", {
  url <- get_url("DEMO_J")

  # CDC documentation URLs include /datafiles/ in path
  expect_true(grepl("/datafiles/", url))
})

# ------------------------------------------------------------------------------
# Comparison and consistency tests
# ------------------------------------------------------------------------------

test_that("get_url returns consistent results for same input", {
  url1 <- get_url("DEMO_J")
  url2 <- get_url("DEMO_J")
  url3 <- get_url("demo_j") # Different case

  expect_equal(url1, url2)
  expect_equal(url1, url3)
})

test_that("get_url returns different URLs for different suffixes", {
  url_b <- get_url("DEMO_B")
  url_j <- get_url("DEMO_J")

  expect_false(identical(url_b, url_j))
  expect_true(grepl("2001", url_b))
  expect_true(grepl("2017", url_j))
})

test_that("get_url returns different URLs for different tables", {
  url_demo <- get_url("DEMO_J")
  url_bmx <- get_url("BMX_J")

  expect_false(identical(url_demo, url_bmx))
  expect_true(grepl("DEMO_J", url_demo))
  expect_true(grepl("BMX_J", url_bmx))
})
