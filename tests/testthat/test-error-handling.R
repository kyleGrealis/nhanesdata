test_that("term_search handles API failures gracefully", {
  local_mocked_bindings(
    nhanesSearch = function(...) stop("Connection error: API unavailable"),
    .package = "nhanesA"
  )

  # Should return empty data.frame and message (not crash)
  expect_message(
    result <- term_search("diabetes"),
    "Unable to search NHANES database"
  )

  # Result should be empty data.frame with correct structure
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_named(
    result,
    c("Variable.Name", "Variable.Description", "Data.File.Name", "Begin.Year")
  )
})

test_that("var_search handles API failures gracefully", {
  local_mocked_bindings(
    nhanesSearchVarName = function(...) {
      stop("Connection error: API unavailable")
    },
    .package = "nhanesA"
  )

  # Should return empty data.frame and message (not crash)
  expect_message(
    result <- var_search("RIAGENDR"),
    "Unable to search NHANES database"
  )

  # Result should be empty data.frame with correct structure
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_named(
    result,
    c(
      "Variable.Name", "Variable.Description", "Data.File.Name",
      "Data.File.Description", "Begin.Year", "EndYear",
      "Component", "UseConstraints"
    )
  )
})

test_that("term_search still handles regex errors by escaping", {
  # This test verifies the nested tryCatch still works for regex issues
  # We'll use a real call since mocking nested tryCatch is complex
  skip_if_offline()

  # Special regex characters should be handled automatically
  expect_no_error({
    result <- term_search("weight (kg)")
  })
})

test_that("read_nhanes handles download and connection errors with helpful messages", {
  local_mocked_bindings(
    read_parquet = function(...) stop("404 Not Found: object does not exist"),
    .package = "arrow"
  )

  expect_error(
    read_nhanes("nonexistent_table"),
    "Failed to load dataset 'NONEXISTENT_TABLE'"
  )

  expect_error(
    read_nhanes("nonexistent_table"),
    "Did you misspell the dataset name?"
  )
})

test_that("read_nhanes validates dataset argument type and length", {
  expect_error(
    read_nhanes(123),
    "`dataset` must be a single character string, not numeric"
  )
  expect_error(
    read_nhanes(NULL),
    "`dataset` must be a single character string, not NULL"
  )
  expect_error(
    read_nhanes(c("demo", "bmx")),
    "`dataset` must be a single character string"
  )
})

test_that("error messages are diplomatic and helpful", {
  local_mocked_bindings(
    nhanesSearch = function(...) stop("Some API error"),
    .package = "nhanesA"
  )

  # Capture the message text
  msgs <- capture_messages(term_search("test"))
  msg_text <- paste(msgs, collapse = " ")

  # Check for diplomatic language (not accusatory)
  expect_match(msg_text, "Unable to search", ignore.case = TRUE)
  expect_match(msg_text, "may be due to", ignore.case = TRUE)
  expect_match(msg_text, "try again", ignore.case = TRUE)

  # Should NOT contain accusatory language
  expect_no_match(msg_text, "broken", ignore.case = TRUE)
  expect_no_match(msg_text, "fault", ignore.case = TRUE)
  expect_no_match(msg_text, "CDC.*down", ignore.case = TRUE)
})
