# 03-analyze.R --- Analysis functions ----
#
# Defines functions only; executed by main.R.

#' Fit the headline model with a bootstrap CI on the slope
#'
#' @param dt A cleaned data.table with columns `value` and `x`.
#' @param n_boot Number of bootstrap replicates.
#' @return A named list: `fit` (lm), `coefs` (data.table), `slope_ci` (numeric).
estimate_model <- function(dt, n_boot = 1000L) {
  fit <- lm(value ~ x, data = dt)

  # Bootstrap the slope --- seed before the randomness step (project seed 888).
  set.seed(888L)
  n      <- nrow(dt)
  slopes <- numeric(n_boot)                       # pre-allocate; never grow with c()
  for (b in seq_len(n_boot)) {
    idx       <- sample.int(n, n, replace = TRUE)
    slopes[b] <- coef(lm(value ~ x, data = dt[idx]))[["x"]]
  }

  list(
    fit      = fit,
    coefs    = as.data.table(summary(fit)$coefficients, keep.rownames = "term"),
    slope_ci = quantile(slopes, c(0.025, 0.975), na.rm = TRUE)
  )
}
