test_that("term_search handles API failures gracefully", {
  # Mock nhanesA::nhanesSearch to simulate API failure
  mockery::stub(term_search, "nhanesA::nhanesSearch", function(...) {
    stop("Connection error: API unavailable")
  })

  # Should return empty data.frame and message (not crash)
  expect_message(
    result <- term_search("diabetes"),
    "Unable to search the NHANES database"
  )

  # Result should be empty data.frame with correct structure
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_named(result, c("Variable.Name", "Variable.Description", "Data.File.Name", "Begin.Year"))
})

test_that("var_search handles API failures gracefully", {
  # Mock nhanesA::nhanesSearchVarName to simulate API failure
  mockery::stub(var_search, "nhanesA::nhanesSearchVarName", function(...) {
    stop("Connection error: API unavailable")
  })

  # Should return empty data.frame and message (not crash)
  expect_message(
    result <- var_search("RIAGENDR"),
    "Unable to search the NHANES database"
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

test_that("error messages are diplomatic and helpful", {
  mockery::stub(term_search, "nhanesA::nhanesSearch", function(...) {
    stop("Some API error")
  })

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
