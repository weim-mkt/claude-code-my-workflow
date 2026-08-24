# 02-clean_data.R --- Data cleaning functions ----
#
# Defines functions only; executed by main.R.

#' Clean the raw dataset
#'
#' Drops rows with a missing id and coerces `value` to numeric. Uses the base
#' pipe with data.table's `_[...]` placeholder, one operation per line.
#'
#' @param dt A data.table of raw data.
#' @return A cleaned data.table.
clean_data <- function(dt) {
  dt |>
    _[!is.na(id)] |>
    _[, value := as.numeric(value)]
}
