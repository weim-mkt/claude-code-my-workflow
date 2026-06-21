# CLAUDE.MD -- Academic Project Development with Claude Code

<!-- HOW TO USE: Replace [BRACKETED PLACEHOLDERS] with your project info.
     Customize Beamer environments and CSS classes for your theme.
     Keep this file under ~150 lines — Claude loads it every session.
     See the guide at docs/workflow-guide.html for full documentation. -->

**Project:** [YOUR PROJECT NAME]
**Institution:** UCL School of Management
**Branch:** main

---

## Core Principles

- **Plan first** -- enter plan mode before non-trivial tasks; save plans to `quality_reports/plans/`
- **Verify after** -- compile/render and confirm output at the end of every task
- **Single source of truth** -- Beamer `.tex` is authoritative; Quarto `.qmd` derives from it
- **Quality gates** -- nothing ships below 80/100
- **[LEARN] tags** -- when corrected, save `[LEARN:category] wrong → right` to [MEMORY.md](MEMORY.md)
- **No em dashes** -- do not use `—` in production prose (slides, manuscripts, Overleaf sources); AI-sounding. Internal working files (session logs, plans, commits, PRs, MEMORY.md) are exempt.

Cross-session context lives in [MEMORY.md](MEMORY.md); past plans, specs, and session logs are in [quality_reports/](quality_reports/).

---

## Folder Structure

```
[YOUR-PROJECT]/
├── CLAUDE.MD                    # This file
├── .claude/                     # Rules, skills, agents, hooks
├── .githooks/                   # Git hooks (activate: git config core.hooksPath .githooks)
├── Bibliography_base.bib        # Centralized bibliography
├── Figures/                     # Figures and images (TikZ outputs, SVGs)
├── Preambles/header.tex         # LaTeX headers
├── Slides/                      # Beamer .tex files
├── Quarto/                      # RevealJS .qmd files + theme
├── docs/                        # GitHub Pages (auto-generated)
├── guide/                       # Quarto-rendered workflow documentation
├── scripts/                     # Utility scripts + analysis pipeline (quality_score.py, sync_to_docs.sh, validators)
│   ├── R/                       # R pipeline (load → clean → analyze → tables → figures) + _outputs/
│   ├── stata/                   # Stata pipeline (.do files + _outputs/); see stata-code-conventions.md
│   └── python/                  # Python pipeline (+ _outputs/)
├── quality_reports/             # Plans, session logs, merge reports, decision records
├── explorations/                # Research sandbox (see rules)
├── templates/                   # Session log, quality report templates
└── master_supporting_docs/      # Papers and existing slides (claim-verifier ground truth)
```

---

## Commands

```bash
# LaTeX (3-pass, XeLaTeX only)
cd Slides && TEXINPUTS=../Preambles:$TEXINPUTS xelatex -interaction=nonstopmode file.tex
BIBINPUTS=..:$BIBINPUTS bibtex file
TEXINPUTS=../Preambles:$TEXINPUTS xelatex -interaction=nonstopmode file.tex
TEXINPUTS=../Preambles:$TEXINPUTS xelatex -interaction=nonstopmode file.tex

# Deploy Quarto to GitHub Pages
./scripts/sync_to_docs.sh LectureN

# Quality score
python scripts/quality_score.py Quarto/file.qmd

# Palette sync (LaTeX ↔ SCSS)
./scripts/check-palette-sync.sh

# Surface-count sync (README ↔ CLAUDE.md ↔ guide ↔ landing page)
./scripts/check-surface-sync.sh

# Activate git pre-commit quality gate (one-time, per clone)
git config core.hooksPath .githooks
```

**Palette contract:** color names in `Preambles/header.tex` must match SCSS variables in `Quarto/theme-template.scss`. See [`Preambles/README.md`](Preambles/README.md).

---

## Quality Thresholds (advisory)

| Score | Checkpoint | Meaning |
|-------|------|---------|
| 80 | Commit | Good enough to save |
| 90 | PR | Ready for deployment |
| 95 | Excellence | Aspirational |

Enforced by `/commit` (halts + asks for override) **and** — once you run `./scripts/install-hooks.sh` — by a real git pre-commit hook (`.githooks/pre-commit`) that runs the surface-sync + quality (≥80) gates on every commit. Bypass sparingly with `SKIP_QUALITY_GATE=1` or `--no-verify`.

---

## Skills Quick Reference

The full table of all skills lives in [README.md](README.md#skills-claudeskills). Most-used, by workflow:

- **Slides / teaching:** `/create-lecture` `/compile-latex` `/deploy` `/qa-quarto` `/slide-excellence` `/syllabus` `/teach-from-paper` `/scaffold-exercises`
- **Papers / review:** `/review-paper` (`--peer`) `/seven-pass-review` `/respond-to-referees` `/verify-claims` `/proofread` `/humanize` `/submission-disclosures`
- **Data / reproducibility:** `/data-analysis` `/did-event-study` `/simulation-study` `/audit-reproducibility` `/diagnose` `/replication-package` `/capture-environment` `/power-analysis` `/disclosure-check`
- **Research / writing:** `/interview-me` `/lit-review` `/research-ideation` `/preregister` `/grant-proposal` `/data-management-plan`
- **Meta / workflow:** `/commit` `/learn` `/new-skill` `/checkpoint` `/context-status` `/deep-audit` `/coauthor-brief` `/triage-inbox` `/codex`

Stata (`/stata-replication`), R packages (`/r-package-check`), TikZ (`/extract-tikz`, `/new-diagram`), and more — see the README for the complete index.

---

<!-- CUSTOMIZE: Replace placeholder rows ([your-env], [.your-class]) with your own.
     Delete the rows marked "(example — delete)" once you've added yours. -->

## Beamer Custom Environments

| Environment | Effect | Use Case |
| --- | --- | --- |
| `[your-env]` | [Description] | [When to use] |
| `keybox` | Gold background box | Key points *(example — delete)* |
| `definitionbox[Title]` | Blue-bordered titled box | Formal definitions *(example — delete)* |

## Quarto CSS Classes

| Class | Effect | Use Case |
| --- | --- | --- |
| `[.your-class]` | [Description] | [When to use] |
| `.smaller` | 85% font | Dense content *(example — delete)* |
| `.positive` | Green bold | Good annotations *(example — delete)* |

---

## Current Project State

| Lecture | Beamer | Quarto | Key Content |
| --- | --- | --- | --- |
| HelloWorld *(sample — delete when ready)* | `HelloWorld.tex` | `HelloWorld.qmd` | Minimal deck to verify setup |
| 1: [Topic] | `Lecture01_Topic.tex` | `Lecture1_Topic.qmd` | [Brief description] |
