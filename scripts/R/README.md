# Analysis Pipeline (`scripts/R/`)

A function-based R pipeline that follows this project's R standard
([`.claude/rules/r-code-conventions.md`](../../.claude/rules/r-code-conventions.md)).

## Layout

| File | Role |
|------|------|
| `main.R` | Entry point. Sources setup + function scripts, then executes the pipeline. |
| `00-setup.R` | Packages (`renv`/`pak`), global variables, seed, and paths. Runs on source. |
| `01-load_data.R` | Defines data-loading functions. |
| `02-clean_data.R` | Defines data-cleaning functions. |
| `03-analyze.R` | Defines analysis / estimation functions. |
| `04-tables.R` | Defines table-output functions. |
| `05-figures.R` | Defines figure functions. |

Each numbered script **only defines functions**; `main.R` sources them in order
and calls them. The numbered prefixes make execution order explicit.

## Run

```bash
Rscript scripts/R/main.R
```

## Conventions baked in

- `data.table` for wrangling (base pipe `|>` with the `_[...]` placeholder).
- `set.seed(888)` immediately before each randomness step.
- All paths via `here::here()`; outputs cached with `fst` (tabular) and `qs2` (model objects).
- Tables exported to LaTeX with `modelsummary` (pass the fitted model, not extracted coefficients).
- Figures use `ggthemes::theme_stata()` and save with `bg = "transparent"`.
- Numerical discipline: pre-allocated vectors, integer literals (`888L`), explicit `na.rm`.

See [`.claude/rules/r-code-conventions.md`](../../.claude/rules/r-code-conventions.md)
for the full standard.
