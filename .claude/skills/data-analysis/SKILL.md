---
name: data-analysis
description: End-to-end R data analysis workflow from exploration through regression to publication-ready tables and figures
argument-hint: "[dataset path or description of analysis goal]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Task"]
---

# Data Analysis Workflow

Run an end-to-end data analysis in R: load, explore, analyze, and produce publication-ready output.

**Input:** `$ARGUMENTS` — a dataset path (e.g., `data/county_panel.csv`) or a description of the analysis goal (e.g., "regress wages on education with state fixed effects using CPS data").

---

## Constraints

- **Follow R code conventions** in `.claude/rules/r-code-conventions.md`
- **Save all scripts** to `scripts/R/` with descriptive names
- **Save all outputs** (figures, tables, cached data) to `output/`
- **Cache data** with `fst::write_fst()` for tabular, `qs2::qs_save()` for model objects
- **Use `ggthemes::theme_stata()`** for all figures
- **Run r-reviewer** on the generated script before presenting results

---

## Workflow Phases

### Phase 1: Setup and Data Loading

1. Read `.claude/rules/r-code-conventions.md` for project standards
2. Create R script with proper header (title, author, purpose, inputs, outputs)
3. Load required packages at top via `library()` (`renv` + `pak` for install)
4. Call `set.seed(888)` before each step involving randomness
5. Load and inspect the dataset

### Phase 2: Exploratory Data Analysis

Generate diagnostic outputs:
- **Summary statistics:** `summary()`, missingness rates, variable types
- **Distributions:** Histograms for key continuous variables
- **Relationships:** Scatter plots, correlation matrices
- **Time patterns:** If panel data, plot trends over time
- **Group comparisons:** If treatment/control, compare pre-treatment means

Save all diagnostic figures to `output/diagnostics/`.

### Phase 3: Main Analysis

Based on the research question:
- **Regression analysis:** Use `fixest` for panel data, `lm`/`glm` for cross-section
- **Standard errors:** Cluster at the appropriate level (document why)
- **Multiple specifications:** Start simple, progressively add controls
- **Effect sizes:** Report standardized effects alongside raw coefficients

### Phase 4: Publication-Ready Output

**Tables:**
- Use `modelsummary` for regression tables (preferred) or `stargazer`
- Include all standard elements: coefficients, SEs, significance stars, N, R-squared
- Export as `.tex` for LaTeX inclusion and `.html` for quick viewing

**Figures:**
- Use `ggplot2` with `ggthemes::theme_stata()`
- Set `bg = "transparent"` for Beamer compatibility
- Include proper axis labels (sentence case, units)
- Export with explicit dimensions: `ggsave(width = X, height = Y)`
- Save as both `.pdf` and `.png`

### Phase 5: Save and Review

1. `fst::write_fst()` for tabular data, `qs2::qs_save()` for model objects
2. Create `output/` subdirectories as needed with `dir.create(..., recursive = TRUE)`
3. Run the r-reviewer agent on the generated script:

```
Delegate to the r-reviewer agent:
"Review the script at scripts/R/[script_name].R"
```

4. Address any Critical or High issues from the review.

---

## Script Structure

Follow this template:

```r
# ============================================================
# [Descriptive Title]
# Author: [from project context]
# Purpose: [What this script does]
# Inputs: [Data files]
# Outputs: [Figures, tables, cached data]
# ============================================================

# 0. Setup ----
library(data.table)
library(fixest)
library(modelsummary)
library(ggplot2)
library(ggthemes)
library(here)
library(fst)
library(qs2)

dir.create(here("output", "analysis"), recursive = TRUE, showWarnings = FALSE)

# 1. Data Loading ----
# dt <- fread(here("data", "raw", "dataset.csv"), encoding = "UTF-8")

# 2. Exploratory Analysis ----
# [Summary stats, diagnostic plots]

# 3. Main Analysis ----
set.seed(888)
# [Regressions, estimation — seed before any randomness step]

# 4. Tables and Figures ----
# [Publication-ready output with theme_stata()]

# 5. Export ----
# fst::write_fst(dt_results, here("output", "analysis", "results.fst"))
# qs2::qs_save(model_fit, here("output", "analysis", "model.qs2"))
# ggsave(here("output", "analysis", "figure.pdf"), width = 12, height = 5, bg = "transparent")
```

---

## Important

- **Reproduce, don't guess.** If the user specifies a regression, run exactly that.
- **Show your work.** Print summary statistics before jumping to regression.
- **Check for issues.** Look for multicollinearity, outliers, perfect prediction.
- **Use relative paths.** All paths relative to repository root.
- **Use `here::here()`.** All paths via `here()` for cross-platform compatibility.
- **No hardcoded values.** Use variables for sample restrictions, date ranges, etc.
