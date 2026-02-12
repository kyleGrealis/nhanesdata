library(testthat)
library(nhanesdata)

# ==============================================================================
# Tests for type harmonization helpers
#
# These tests verify that .harmonize_column_types() and
# .translate_numeric_columns() correctly handle the type mismatches that occur
# when nhanesA returns the same variable as a factor (with text labels) in one
# NHANES cycle and as plain numeric (with CDC codes) in another.
#
# Background: nhanesA::nhanes() uses nhanesTranslate() to convert numeric CDC
# codes into factor labels by scraping the CDC codebook HTML. When a cycle's
# codebook is unavailable, the column stays numeric. The old harmonization code
# used typeof() to detect mismatches, but typeof(factor) returns "integer"
# (the storage type), so factor-vs-double was treated as integer-vs-double and
# as.double(factor) returned level indices instead of actual values --
# corrupting data for columns with non-sequential CDC codes.
# ==============================================================================


# ==============================================================================
# .harmonize_column_types() tests
# ==============================================================================

# --- Factor vs numeric: the critical bug fix ---

test_that("factor vs double converts both to character, not double", {
  # This is the exact scenario that caused data corruption: a factor column

  # meeting a double column. The old code called as.double(factor), which
  # returned level indices (1, 2, 3) instead of the original CDC codes
  # (e.g., 1, 3, 4 for BMIWT).
  df1 <- data.frame(
    x = factor(
      c("Could not obtain", "Clothing", "Medical appliance"),
      levels = c("Could not obtain", "Clothing", "Medical appliance")
    )
  )
  df2 <- data.frame(x = c(1.0, 3.0, 4.0))

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "character")
  expect_type(result$new$x, "character")
  # Factor labels preserved verbatim
  expect_equal(
    result$existing$x,
    c("Could not obtain", "Clothing", "Medical appliance")
  )
  # Numeric codes become their string representation
  expect_equal(result$new$x, c("1", "3", "4"))
})

test_that("factor vs integer converts both to character", {
  df1 <- data.frame(x = factor(c("Complete", "Partial")))
  df2 <- data.frame(x = c(1L, 2L))

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "character")
  expect_type(result$new$x, "character")
  expect_equal(result$existing$x, c("Complete", "Partial"))
  expect_equal(result$new$x, c("1", "2"))
})

test_that("numeric vs factor converts both to character (reversed order)", {
  # Same as above but the numeric column is in existing_df
  df1 <- data.frame(x = c(1.0, 3.0, 4.0))
  df2 <- data.frame(
    x = factor(c("Could not obtain", "Clothing", "Medical appliance"))
  )

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "character")
  expect_type(result$new$x, "character")
})

# --- Factor vs factor ---

test_that("factor vs factor with different levels converts to character", {
  df1 <- data.frame(
    x = factor(c("A", "B"), levels = c("A", "B"))
  )
  df2 <- data.frame(
    x = factor(c("C", "D"), levels = c("C", "D"))
  )

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "character")
  expect_type(result$new$x, "character")
  expect_equal(result$existing$x, c("A", "B"))
  expect_equal(result$new$x, c("C", "D"))
})

# --- Factor vs character ---

test_that("factor vs character converts factor to character", {
  df1 <- data.frame(x = factor(c("A", "B")))
  df2 <- data.frame(x = c("C", "D"), stringsAsFactors = FALSE)

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "character")
  expect_type(result$new$x, "character")
})

test_that("character vs factor converts factor to character", {
  df1 <- data.frame(x = c("A", "B"), stringsAsFactors = FALSE)
  df2 <- data.frame(x = factor(c("C", "D")))

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "character")
  expect_type(result$new$x, "character")
})

# --- Numeric type promotion ---

test_that("integer vs double converts both to double", {
  df1 <- data.frame(x = c(1L, 2L, 3L))
  df2 <- data.frame(x = c(1.5, 2.5, 3.5))

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "double")
  expect_type(result$new$x, "double")
  # Values preserved
  expect_equal(result$existing$x, c(1, 2, 3))
  expect_equal(result$new$x, c(1.5, 2.5, 3.5))
})

# --- No-op cases ---

test_that("matching types are left unchanged", {
  df1 <- data.frame(x = c(1.0, 2.0))
  df2 <- data.frame(x = c(3.0, 4.0))

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_equal(result$existing$x, c(1.0, 2.0))
  expect_equal(result$new$x, c(3.0, 4.0))
})

test_that("matching character types are left unchanged", {
  df1 <- data.frame(x = c("a", "b"), stringsAsFactors = FALSE)
  df2 <- data.frame(x = c("c", "d"), stringsAsFactors = FALSE)

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "character")
  expect_equal(result$existing$x, c("a", "b"))
})

# --- skip_cols ---

test_that("skip_cols are not harmonized", {
  df1 <- data.frame(year = 1999L, x = factor("A"))
  df2 <- data.frame(year = 2001L, x = 1.0)

  result <- nhanesdata:::.harmonize_column_types(
    df1, df2,
    skip_cols = c("year")
  )

  # year left as-is (integer in df1)
  expect_type(result$existing$year, "integer")
  # x was harmonized
  expect_type(result$existing$x, "character")
})

test_that("default skip_cols includes year and seqn", {
  df1 <- data.frame(year = 1999L, seqn = 1L, x = factor("A"))
  df2 <- data.frame(year = 2001.0, seqn = 2.0, x = 1.0)

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  # year and seqn left untouched
  expect_type(result$existing$year, "integer")
  expect_type(result$existing$seqn, "integer")
  # x was harmonized
  expect_type(result$existing$x, "character")
})

# --- All-NA columns ---

test_that("all-NA column in existing_df adopts new_df type", {
  # When existing side is all-NA, it should adopt new_df's type so
  # bind_rows() doesn't fail on type mismatch. This happens when a
  # column like BMIHEAD exists in some cycles but not others.
  df1 <- data.frame(x = c(NA, NA, NA)) # logical NA
  df2 <- data.frame(x = factor(c("A", "B", "C"))) # factor

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  # existing should be coerced to match new_df's type (factor -> character
  # doesn't apply here since we're matching the class, which is "factor")
  expect_true(is.factor(result$existing$x))
  expect_true(all(is.na(result$existing$x)))
})

test_that("all-NA character column adopts numeric type from new_df", {
  # Common real-world case: column appeared in earlier cycle as character,
  # all its rows have since been NA, and the new cycle has double values.
  df1 <- data.frame(
    x = c(NA_character_, NA_character_, NA_character_)
  )
  df2 <- data.frame(x = c(1.5, 2.5, 3.5))

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "double")
  expect_true(all(is.na(result$existing$x)))
  expect_type(result$new$x, "double")
  # After harmonization, bind_rows() should succeed
  expect_no_error(dplyr::bind_rows(result$existing, result$new))
})

test_that("all-NA column in new_df adopts existing_df type", {
  df1 <- data.frame(x = c(1.0, 2.0, 3.0))
  df2 <- data.frame(x = c(NA, NA, NA)) # logical NA

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "double")
  # new_df's NA column should now be double to match existing
  expect_type(result$new$x, "double")
  expect_true(all(is.na(result$new$x)))
  expect_no_error(dplyr::bind_rows(result$existing, result$new))
})

# --- Edge cases ---

test_that("factor with numeric-looking levels handles correctly", {
  # Some CDC factors have levels that look like numbers (e.g., "1", "2", "3")
  df1 <- data.frame(x = factor(c("1", "2", "3")))
  df2 <- data.frame(x = c(1.0, 2.0, 3.0))

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "character")
  expect_type(result$new$x, "character")
  expect_equal(result$existing$x, c("1", "2", "3"))
  expect_equal(result$new$x, c("1", "2", "3"))
})

test_that("ordered factor is treated as factor", {
  df1 <- data.frame(
    x = ordered(
      c("Low", "Med", "High"),
      levels = c("Low", "Med", "High")
    )
  )
  df2 <- data.frame(x = c(1.0, 2.0, 3.0))

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "character")
  expect_type(result$new$x, "character")
  expect_equal(result$existing$x, c("Low", "Med", "High"))
})

test_that("logical vs numeric converts to character", {
  df1 <- data.frame(x = c(TRUE, FALSE, TRUE))
  df2 <- data.frame(x = c(1.0, 0.0, 1.0))

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_type(result$existing$x, "character")
  expect_type(result$new$x, "character")
})

# --- Bindability ---

test_that("harmonized data frames are bindable with bind_rows", {
  df1 <- data.frame(
    year = 2011L,
    seqn = 1L,
    status = c(1.0, 2.0, 3.0),
    label = factor(c("A", "B", "C")),
    score = c(10L, 20L, 30L)
  )
  df2 <- data.frame(
    year = 2013L,
    seqn = 2L,
    status = factor(c("Complete", "Partial", "None")),
    label = c("D", "E", "F"),
    score = c(10.5, 20.5, 30.5)
  )

  result <- nhanesdata:::.harmonize_column_types(df1, df2)

  expect_no_error(dplyr::bind_rows(result$existing, result$new))

  combined <- dplyr::bind_rows(result$existing, result$new)
  expect_equal(nrow(combined), 6)
})


# ==============================================================================
# .translate_numeric_columns() tests
# ==============================================================================

test_that("numeric column is translated using reference table", {
  df <- data.frame(
    year = 2011L,
    bmiwt = c(1, 3, 4, NA)
  )

  # Simulated translation table matching nhanesTranslate() output format
  ref <- list(
    BMIWT = data.frame(
      Code.or.Value = c("1", "3", "4", "."),
      Value.Description = c(
        "Could not obtain", "Clothing", "Medical appliance", "Missing"
      ),
      stringsAsFactors = FALSE
    )
  )

  result <- nhanesdata:::.translate_numeric_columns(df, ref)

  expect_type(result$bmiwt, "character")
  expect_equal(
    result$bmiwt,
    c("Could not obtain", "Clothing", "Medical appliance", NA)
  )
})

test_that("factor column is not re-translated", {
  # If nhanesA already translated the column, skip it
  df <- data.frame(
    bmiwt = factor(
      c("Could not obtain", "Clothing"),
      levels = c("Could not obtain", "Clothing", "Medical appliance")
    )
  )

  ref <- list(
    BMIWT = data.frame(
      Code.or.Value = c("1", "3", "4", "."),
      Value.Description = c(
        "Could not obtain", "Clothing", "Medical appliance", "Missing"
      ),
      stringsAsFactors = FALSE
    )
  )

  result <- nhanesdata:::.translate_numeric_columns(df, ref)

  # Should still be a factor, untouched
  expect_true(is.factor(result$bmiwt))
})

test_that("character column is not re-translated", {
  df <- data.frame(
    bmiwt = c("Could not obtain", "Clothing"),
    stringsAsFactors = FALSE
  )

  ref <- list(
    BMIWT = data.frame(
      Code.or.Value = c("1", "3", "4"),
      Value.Description = c(
        "Could not obtain", "Clothing", "Medical appliance"
      ),
      stringsAsFactors = FALSE
    )
  )

  result <- nhanesdata:::.translate_numeric_columns(df, ref)

  expect_type(result$bmiwt, "character")
  expect_equal(result$bmiwt, c("Could not obtain", "Clothing"))
})

test_that("NULL reference_translations returns data unchanged", {
  df <- data.frame(x = c(1, 2, 3))

  result <- nhanesdata:::.translate_numeric_columns(df, NULL)

  expect_equal(result, df)
})

test_that("empty reference_translations returns data unchanged", {
  df <- data.frame(x = c(1, 2, 3))

  result <- nhanesdata:::.translate_numeric_columns(df, list())

  expect_equal(result, df)
})

test_that("column not in reference_translations is left unchanged", {
  df <- data.frame(
    bmiwt = c(1, 3, 4),
    bmxht = c(170.5, 165.2, 180.0)
  )

  ref <- list(
    BMIWT = data.frame(
      Code.or.Value = c("1", "3", "4"),
      Value.Description = c(
        "Could not obtain", "Clothing", "Medical appliance"
      ),
      stringsAsFactors = FALSE
    )
  )

  result <- nhanesdata:::.translate_numeric_columns(df, ref)

  # bmiwt translated
  expect_type(result$bmiwt, "character")
  # bmxht has no translation table, stays numeric
  expect_type(result$bmxht, "double")
})

test_that("numeric code not in translation table becomes its string form", {
  # A cycle might have a code that wasn't in the reference cycle's codebook
  df <- data.frame(bmiwt = c(1, 3, 4, 99))

  ref <- list(
    BMIWT = data.frame(
      Code.or.Value = c("1", "3", "4"),
      Value.Description = c(
        "Could not obtain", "Clothing", "Medical appliance"
      ),
      stringsAsFactors = FALSE
    )
  )

  result <- nhanesdata:::.translate_numeric_columns(df, ref)

  expect_type(result$bmiwt, "character")
  # Known codes get labels, unknown code 99 becomes "99"
  expect_equal(
    result$bmiwt,
    c("Could not obtain", "Clothing", "Medical appliance", "99")
  )
})

test_that("all-NA numeric column is skipped", {
  df <- data.frame(bmiwt = c(NA_real_, NA_real_, NA_real_))

  ref <- list(
    BMIWT = data.frame(
      Code.or.Value = c("1", "3"),
      Value.Description = c("Could not obtain", "Clothing"),
      stringsAsFactors = FALSE
    )
  )

  result <- nhanesdata:::.translate_numeric_columns(df, ref)

  # Should stay as numeric NA, not translated
  expect_type(result$bmiwt, "double")
})

test_that("continuous variables with Range of Values are not translated", {
  # RIDAGEYR has "Range of Values" in the codebook, meaning it's continuous.
  # Only the top-coded value (80) has a text description. Translating this
  # column would corrupt it: 80 becomes "80 years of age and over" while
  # all other ages become their string form, destroying the numeric column.
  df <- data.frame(ridageyr = c(25, 53, 80, 79, NA))

  ref <- list(
    RIDAGEYR = data.frame(
      Code.or.Value = c("0 to 79", "80", "."),
      Value.Description = c(
        "Range of Values",
        "80 years of age and over",
        "Missing"
      ),
      stringsAsFactors = FALSE
    )
  )

  result <- nhanesdata:::.translate_numeric_columns(df, ref)

  # Column should stay numeric — NOT converted to character
  expect_type(result$ridageyr, "double")
  expect_equal(result$ridageyr, c(25, 53, 80, 79, NA))
})

test_that("continuous variables with Range of Values (income ratio) skipped", {
  # INDFMPIR: poverty income ratio, top-coded at 5
  df <- data.frame(indfmpir = c(0.5, 2.3, 5.0, NA))

  ref <- list(
    INDFMPIR = data.frame(
      Code.or.Value = c("0 to 4.99", "5", "."),
      Value.Description = c(
        "Range of Values",
        "Value greater than or equal to 5.00",
        "Missing"
      ),
      stringsAsFactors = FALSE
    )
  )

  result <- nhanesdata:::.translate_numeric_columns(df, ref)

  expect_type(result$indfmpir, "double")
  expect_equal(result$indfmpir, c(0.5, 2.3, 5.0, NA))
})

test_that("translation handles lowercase column names from clean_names", {
  # pull_nhanes() uses janitor::clean_names() which lowercases everything.
  # Translation tables from nhanesTranslate() use UPPERCASE names.
  # .translate_numeric_columns() must bridge this gap.
  df <- data.frame(bmdstats = c(1, 2, 3, 4))

  ref <- list(
    BMDSTATS = data.frame(
      Code.or.Value = c("1", "2", "3", "4"),
      Value.Description = c(
        "Complete data for age group",
        "Partial:  Only height and weight obtained",
        "Other partial exam",
        "No body measures exam data"
      ),
      stringsAsFactors = FALSE
    )
  )

  result <- nhanesdata:::.translate_numeric_columns(df, ref)

  expect_type(result$bmdstats, "character")
  expect_equal(result$bmdstats[1], "Complete data for age group")
  expect_equal(result$bmdstats[4], "No body measures exam data")
})
