# main.R --- Pipeline entry point ----
#
# Run with:  Rscript scripts/R/main.R
#
# Sources setup + the numbered function scripts, then executes the pipeline in
# order. Each numbered script only *defines* functions; orchestration lives here.

# Source setup and function definitions, in order ----
source(here::here("scripts", "R", "00-setup.R"))
source(here::here("scripts", "R", "01-load_data.R"))
source(here::here("scripts", "R", "02-clean_data.R"))
source(here::here("scripts", "R", "03-analyze.R"))
source(here::here("scripts", "R", "04-tables.R"))
source(here::here("scripts", "R", "05-figures.R"))

# Execute the pipeline ----
raw     <- load_raw_data()
cleaned <- clean_data(raw)
fst::write_fst(cleaned, here::here("data", "cleaned", "analysis.fst"))

results <- estimate_model(cleaned)
qs2::qs_save(results$fit, here::here("output", "model.qs2"))

write_main_table(results$fit)
plot_main_figure(cleaned)

message("Pipeline complete. Outputs in ", here::here("output"), ".")
