# Plan: Update Rule Metadata Paths — scripts/ → code/, remove Figures/*.R

**Status:** DRAFT
**Date:** 2026-03-21

## Context

Project structure uses `./code/` for all R scripts (including figure generation). Metadata paths in rules still reference `scripts/**/*.R` and `Figures/**/*.R`. Also, inline references to `scripts/R/` need updating.

## Changes

### 1. Metadata paths: `scripts/**/*.R` → `code/**/*.R`

| File | Line |
|------|------|
| `.claude/rules/r-code-conventions.md` | 5 |
| `.claude/rules/quality-gates.md` | 5 |
| `.claude/rules/replication-protocol.md` | 3 |
| `.claude/rules/orchestrator-research.md` | 3 |
| `.claude/rules/knowledge-base-template.md` | 5 |

### 2. Metadata paths: remove `Figures/**/*.R`

All R scripts live in `code/`, so remove `Figures/**/*.R` from:

| File | Line |
|------|------|
| `.claude/rules/r-code-conventions.md` | 4 |
| `.claude/rules/replication-protocol.md` | 4 |
| `.claude/rules/orchestrator-research.md` | 5 |

### 3. Inline `scripts/R/` references → `code/`

| File | Current | New |
|------|---------|-----|
| `.claude/skills/data-analysis/SKILL.md:19` | `scripts/R/` | `code/` |
| `.claude/skills/data-analysis/SKILL.md:78` | `scripts/R/[script_name].R` | `code/[script_name].R` |
| `.claude/skills/review-r/SKILL.md:17` | `scripts/R/` and `Figures/*/` | `code/` |
| `.claude/agents/verifier.md:38` | `Rscript scripts/R/FILENAME.R` | `Rscript code/FILENAME.R` |
| `.claude/rules/verification-protocol.md:35` | `Rscript scripts/R/filename.R` | `Rscript code/filename.R` |

### NOT changing (separate task)

- `./scripts/sync_to_docs.sh` references (infrastructure utility, stays in `scripts/`)
- `./scripts/quality_score.py` references (same)
- Future: consider moving utilities to `.claude/scripts/`

## Verification

- Grep `.claude/` for remaining `scripts/**/*.R` and `Figures/**/*.R` metadata paths
- Grep for remaining `scripts/R/` inline references
