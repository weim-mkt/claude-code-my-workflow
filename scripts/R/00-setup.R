# 00-setup.R --- Packages and global environment ----
#
# Sourced first by main.R. Loads packages and sets global options, the project
# seed, and output paths. This is the one script that runs on source rather than
# only defining functions.

# Packages ----
# Managed by renv with the pak backend. On a fresh clone run renv::restore().
library(data.table)
library(here)
library(ggplot2)
library(ggthemes)
library(fst)
library(qs2)
library(modelsummary)

# Global options ----
options(
  datatable.print.class = TRUE,
  stringsAsFactors      = FALSE
)

# Reproducibility ----
# Project default seed. set.seed(SEED) is called inside each function before a
# randomness step (not once at the top), per r-code-conventions.md.
SEED <- 888L

# Paths ----
# Everything resolves from the project root via here::here().
dir_raw     <- here::here("data", "raw")
dir_cleaned <- here::here("data", "cleaned")
dir_output  <- here::here("output")

# Create output directories if missing ----
for (d in c(dir_cleaned, dir_output)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# Default ggplot theme ----
theme_set(ggthemes::theme_stata())
