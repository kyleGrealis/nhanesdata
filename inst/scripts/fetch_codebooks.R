# fetch_codebooks.R
# Fetch and cache codebooks for a single NHANES table code.
# Usage: Rscript inst/scripts/fetch_codebooks.R DEMO_L
#        Rscript inst/scripts/fetch_codebooks.R DEMO

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) stop("Usage: Rscript fetch_codebooks.R TABLE_CODE")

table_code <- toupper(args[1])
cache_dir <- "inst/cache/codebooks"
if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)

cache_file <- file.path(cache_dir, paste0(table_code, ".rds"))

if (file.exists(cache_file)) {
  message(table_code, ": already cached")
  quit("no", status = 0)
}

message(table_code, ": fetching from CDC...")
result <- tryCatch(
  suppressMessages(suppressWarnings(nhanesA::nhanesTranslate(table_code))),
  error = function(e) {
    message("  ERROR: ", e$message)
    NULL
  }
)

if (is.null(result) || length(result) == 0) {
  saveRDS(list(.no_codebook = TRUE), cache_file)
  message(table_code, ": no codebook available")
} else {
  saveRDS(result, cache_file)
  message(table_code, ": ", length(result), " variables cached")
}
