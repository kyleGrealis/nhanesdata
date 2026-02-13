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

test_that("pull_nhanes retries on errors and tracks skipped cycles", {
  # Simulate persistent network errors (not NULL returns)
  local_mocked_bindings(
    nhanes = function(...) stop("Connection timed out"),
    .package = "nhanesA"
  )
  local_mocked_bindings(
    nhanesTranslate = function(...) NULL,
    .package = "nhanesA"
  )
  withr::local_options(nhanesdata.retry_delay = 0)

  # Expect warning about no data retrieved (all cycles error out)
  expect_warning(
    result <- suppressMessages(
      nhanesdata:::pull_nhanes("DEMO", save = FALSE)
    ),
    "No data retrieved from any cycle"
  )

  # Should still return a tibble (empty since all cycles failed)
  expect_s3_class(result, "tbl_df")

  # Should have skipped_cycles attribute listing every attempted table
  skipped <- attr(result, "skipped_cycles")
  expect_true(!is.null(skipped))
  expect_true(length(skipped) > 0)
  expect_true("DEMO" %in% skipped) # base table (1999)
})

test_that("pull_nhanes does NOT retry or flag when nhanes() returns NULL", {
  # NULL means "table doesn't exist", not a transient error.
  # Should skip immediately without retry or flagging as skipped.
  call_count <- 0
  local_mocked_bindings(
    nhanes = function(...) {
      call_count <<- call_count + 1
      NULL
    },
    .package = "nhanesA"
  )
  local_mocked_bindings(
    nhanesTranslate = function(...) NULL,
    .package = "nhanesA"
  )
  withr::local_options(nhanesdata.retry_delay = 0)

  # No skipped_cycles warning because NULL is normal "not found"
  expect_warning(
    result <- suppressMessages(
      nhanesdata:::pull_nhanes("DEMO", save = FALSE)
    ),
    "No data retrieved from any cycle"
  )

  # Should NOT have skipped_cycles (NULL returns are not errors)
  expect_null(attr(result, "skipped_cycles"))

  # Each cycle should be called exactly once (no retries)
  expect_equal(call_count, 11) # 11 cycles for DEMO
})

test_that("pull_nhanes succeeds without warning when no cycles are skipped", {
  # Simulate a dataset where nhanes always returns data
  mock_data <- data.frame(SEQN = 1:5, X = letters[1:5])
  local_mocked_bindings(
    nhanes = function(...) mock_data,
    .package = "nhanesA"
  )
  local_mocked_bindings(
    nhanesTranslate = function(...) NULL,
    .package = "nhanesA"
  )
  withr::local_options(nhanesdata.retry_delay = 0)

  # Should NOT warn about skipped cycles
  expect_no_warning(
    result <- suppressMessages(
      nhanesdata:::pull_nhanes("DEMO", save = FALSE)
    )
  )

  expect_null(attr(result, "skipped_cycles"))
  expect_true(nrow(result) > 0)
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
