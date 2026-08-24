# 05-figures.R --- Figure functions ----
#
# Defines functions only; executed by main.R.

#' Plot the headline figure and save it for Beamer
#'
#' @param dt A cleaned data.table with columns `x` and `value`.
#' @param path Output path for the figure (PDF).
#' @return Invisibly, the path written.
plot_main_figure <- function(dt, path = here::here("output", "fig_main.pdf")) {
  p <- ggplot(dt, aes(x = x, y = value)) +
    geom_point(alpha = 0.6) +
    labs(x = "x", y = "value") +
    ggthemes::theme_stata()

  ggsave(path, plot = p, width = 12, height = 5, bg = "transparent")
  invisible(path)
}
