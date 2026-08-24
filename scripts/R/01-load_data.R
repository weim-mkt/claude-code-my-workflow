# 01-load_data.R --- Data loading functions ----
#
# Defines functions only; executed by main.R.

#' Load the raw dataset
#'
#' @param path Path to the raw CSV. Defaults to the project's raw-data dir.
#' @return A data.table of the raw data.
load_raw_data <- function(path = here::here("data", "raw", "dataset.csv")) {
  fread(path, encoding = "UTF-8")
}
