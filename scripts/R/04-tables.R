# 04-tables.R --- Table functions ----
#
# Defines functions only; executed by main.R.

#' Write the main results table to LaTeX with modelsummary
#'
#' Exports one or more fitted models to a LaTeX table. Pass the model object(s)
#' (e.g. an `lm` / `feols` fit), not pre-extracted coefficients --- modelsummary
#' formats estimates, SEs, stars, and goodness-of-fit rows itself.
#'
#' @param models A model object, or a named list of models for side-by-side columns.
#' @param path Output path for the .tex table. Format is inferred from the extension.
#' @return Invisibly, the path written.
write_main_table <- function(models, path = here::here("output", "tab_main.tex")) {
  # A bare model becomes a single named column; a named list gives one column each.
  if (!inherits(models, "list")) models <- list("(1)" = models)

  modelsummary::modelsummary(
    models,
    output   = path,                                   # .tex -> LaTeX table
    stars    = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
    gof_omit = "AIC|BIC|Log.Lik|RMSE",
    escape   = FALSE                                   # keep LaTeX in coef labels
  )
  invisible(path)
}
