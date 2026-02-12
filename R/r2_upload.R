#' Upload a dataset to Cloudflare R2 bucket
#'
#' This function uploads an R object (typically a data frame) to a specified
#' Cloudflare R2 bucket as a flat parquet file.
#'
#' @details
#' Authentication requires three environment variables to be set:
#' \itemize{
#'   \item `R2_ACCOUNT_ID`: Your Cloudflare account ID.
#'   \item `R2_ACCESS_KEY_ID`: Your R2 access key ID.
#'   \item `R2_SECRET_ACCESS_KEY`: Your R2 secret access key.
#' }
#'
#' The function uploads files to the bucket root, creating URLs like:
#' `https://bucket-url.com/demo.parquet`. This flat structure is required
#' for the `read_nhanes()` function to work correctly.
#'
#' @param x The object to upload (typically a data frame or tibble).
#' @param name The name for the file (without extension). Will be saved as
#'   `{name}.parquet` in the bucket root.
#' @param bucket The name of the R2 bucket to write to.
#'
#' @return Invisibly returns NULL after successful upload. Prints a success
#'   message showing the uploaded filename and bucket name.
#'
#' @examples
#' \dontrun{
#' # Set up authentication in .Renviron or environment
#' # R2_ACCOUNT_ID=your_account_id
#' # R2_ACCESS_KEY_ID=your_access_key
#' # R2_SECRET_ACCESS_KEY=your_secret_key
#'
#' # Upload a dataset
#' demo_data <- pull_nhanes("DEMO")
#' nhanes_r2_upload(
#'   x = demo_data,
#'   name = "demo",
#'   bucket = "nhanes-data"
#' )
#' # Creates: demo.parquet at bucket root
#' }
#'
#' @family data storage functions
#' @noRd
nhanes_r2_upload <- function(x, name, bucket) {
  # Check for required packages
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop(
      "Package 'arrow' is required for nhanes_r2_upload().\n",
      "Install with: install.packages('arrow')",
      call. = FALSE
    )
  }

  if (!requireNamespace("paws.storage", quietly = TRUE)) {
    stop(
      "Package 'paws.storage' is required for nhanes_r2_upload().\n",
      "Install with: install.packages('paws.storage')",
      call. = FALSE
    )
  }

  # Check for required environment variables
  required_vars <- c("R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY")
  missing_vars <- required_vars[
    !vapply(required_vars, function(v) nzchar(Sys.getenv(v)), logical(1))
  ]

  if (length(missing_vars) > 0) {
    stop(
      "Cannot find required environment variables for R2 authentication: ",
      paste(missing_vars, collapse = ", "),
      call. = FALSE
    )
  }

  # Create temporary parquet file
  temp_file <- tempfile(fileext = ".parquet")
  on.exit(unlink(temp_file), add = TRUE)

  arrow::write_parquet(x, temp_file)

  # Construct endpoint URL
  endpoint <- sprintf(
    "https://%s.r2.cloudflarestorage.com",
    Sys.getenv("R2_ACCOUNT_ID")
  )

  # Configure S3 client for R2
  s3 <- paws.storage::s3(
    config = list(
      credentials = list(
        creds = list(
          access_key_id = Sys.getenv("R2_ACCESS_KEY_ID"),
          secret_access_key = Sys.getenv("R2_SECRET_ACCESS_KEY")
        )
      ),
      endpoint = endpoint,
      region = "auto"
    )
  )

  # Upload to bucket root
  key_name <- paste0(name, ".parquet")

  tryCatch(
    {
      s3$put_object(
        Bucket = bucket,
        Key = key_name,
        Body = temp_file
      )
      message(sprintf("Uploaded %s to %s", key_name, bucket))
    },
    error = function(e) {
      stop(
        sprintf("Failed to upload to R2: %s", conditionMessage(e)),
        call. = FALSE
      )
    }
  )

  invisible(NULL)
}
