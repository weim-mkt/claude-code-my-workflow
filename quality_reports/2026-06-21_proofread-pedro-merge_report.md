# Proofread Report — after merging upstream (Pedro) v2.0 + v2.1

**Date:** 2026-06-21
**Scope:** ~90 source files the merge touched (commit `758223e`), generated HTML excluded.
**Method:** 17 file-bucket reviewers + 3 cross-cutting lenses (cross-refs / merge-coherence / terminology); every CRITICAL/MAJOR finding adversarially re-verified in a fresh claim-verifier context (110 files, 33 agents, **0 false positives dropped**).
**Em-dashes:** out of scope (per user).

---

## Outcome

- **29 CRITICAL/MAJOR** confirmed; after dedup, **~13 distinct substantive issues + a CHANGELOG cluster**, plus ~24 minor nits.
- Each finding classified by **origin** (checked against `upstream/main`):
  - **Fork-local / fork-induced (4) → FIXED.** Pedro's copy is correct for him; he will not fix these.
  - **Upstream (the rest) → LEFT AS-IS** by user decision, to minimize divergence and avoid merge conflicts. Recorded below; Pedro may fix at the source.
- Mechanical layer was already clean: no conflict markers; surface-sync passes (53 skills / 18 agents / 32 rules / 7 hooks); model versions current. Re-verified clean after the fixes.

---

## FIXED (fork-local / fork-induced) — 2026-06-21

| ID | File:line | Issue | Fix applied |
|----|-----------|-------|-------------|
| A1 | `CHANGELOG.md` L160 & L451–455 | "Fork delta" notes claimed, in present tense, a `writing-style.md` rule, `check-code-path.sh` hook, `.githooks/post-merge`, the `code/` R convention, and "27 rules" — all reverted 2026-06-21; none exist. **Fork-local content.** | Added dated **"Superseded 2026-06-21"** annotations to both blocks (history preserved; no live counts restated, per `summary-parity.md`). |
| A2 | `CLAUDE.md` L74 | Comment `# Activate git post-merge drift guard` — that hook was removed; the command now activates only the pre-commit gate. **Fork-local.** | Reworded to `# Activate git pre-commit quality gate (one-time, per clone)`. |
| A4 | `guide/workflow-guide.qmd` L921 | Statusline troubleshooting told the user to read a `[BYPASS]`/`[PLAN]`/`[AUTO-EDIT]`/`[PROMPT]` permission badge. **Fork-induced:** your commit 5170121 dropped the badge; upstream still has it. | Rewrote step 1 to point at Claude Code's input box / `Shift+Tab` / `/permission-check`. Re-rendered `guide/` + `docs/` HTML. |
| A5 | `guide/workflow-guide.qmd` L1192 | "the monitor uses tool call count as a proxy" — **fork-induced:** your commit 3b9c645 switched it to live token usage; upstream still uses tool-count. | Rewrote to describe the live-token estimate with tool-count fallback. Re-rendered `guide/` + `docs/` HTML. |

**Files changed:** `CHANGELOG.md`, `CLAUDE.md`, `guide/workflow-guide.qmd`, `guide/workflow-guide.html`, `docs/workflow-guide.html`. Gates re-run green.

---

## LEFT AS-IS — upstream bugs (local record)

All of the following exist verbatim in `pedrohcgs/claude-code-my-workflow@main`, so they are Pedro's to fix. **Decision (2026-06-21): leave untouched** — do not edit, do not submit upstream. Kept here only as a record; if Pedro fixes them, the next merge clears them. If any individual item ever bites this fork, revisit per-item.

### Cross-refs / coherence
| File:line | Issue | If ever fixed |
|-----------|-------|---------------|
| `README.md` L421 | Version pin `git checkout v2.0.0 (current as of 2026-06-09)` — latest is v2.1.0/2026-06-10. (Pedro's own README is also stale.) | → `v2.1.0` (2026-06-10) |
| `README.md` L266–267 + `triage-inbox/SKILL.md` L60,78,109,117 | `/new-referee-project` advertised as a runnable action 5×; **the skill does not exist in your repo or any upstream branch** (unbuilt skill Pedro references). | ship skill / reword / mark planned |
| `.claude/references/prompt-formatting-core.md` L3 vs L64,170,176 + §174–180 | Header says `/prompt` & `/prompt-only` were retired in v2.0; body still describes them as live callable skills. | recast body to prompt-shaping habit vs `/interview-me` |
| `.claude/skills/review-paper/SKILL.md` L435 | "journal-profiles.md covers 5 econ journals" — stale; it now also ships 3 poli-sci (APSR/AJPS/JOP). | update to 5 econ + 3 poli-sci |
| `.claude/skills/teach-from-paper/SKILL.md` L109 | "The **Phase 5** exercise brief" — skill has only Phases 0–3; brief is Phase 3 (L102 says so). | Phase 5 → Phase 3 |

### Stale counts / enumerations (guide — author: Pedro)
| File:line | Issue | If ever fixed |
|-----------|-------|---------------|
| `guide` L889 | "Claude Code has **five** permission modes" over a **six**-row table. | five → six |
| `guide` L1725, L2336 | "**JoE**" listed as a shipped journal profile; the actual fifth econ profile is **ReStud**. | JoE → ReStud (2×) |
| `guide` L158, L2718 | Guide says "53 skills" but the "All Skills" appendix has **51 rows** — missing `/diagnose` and `/submission-disclosures`. | add 2 rows |

### Consistency / casing
| File:line | Issue | If ever fixed |
|-----------|-------|---------------|
| `.claude/skills/did-event-study/SKILL.md` L142 | `scripts/Stata/` (capital S) vs canonical `scripts/stata/` (34 other lowercase refs). **MAJOR.** | scripts/Stata/ → scripts/stata/ |
| `.claude/agents/methods-referee.md` L31 | `*JoP*` vs `JOP` one line later. | *JoP* → JOP |
| `README.md` L397 | `plotly charts` vs guide prose `Plotly`. | plotly → Plotly |
| `CLAUDE.md` L1, L31 | Title/tree write `CLAUDE.MD` (uppercase ext); file is `CLAUDE.md`. | CLAUDE.MD → CLAUDE.md |
| `.claude/agents/quarto-critic.md` L107–108 | `LectureXX` (Beamer) vs `LectureX` (Quarto) placeholder mismatch. | unify placeholder |
| `.claude/references/prompt-formatting-core.md` L45 | Example uses `CRITICAL / IMPORTANT / MINOR`; canonical vocab is `MAJOR`. | IMPORTANT → MAJOR |
| `templates/skill-template.md` L151 | "at 146 lines" — count drift (this repo's CLAUDE.md is 134; verify against Pedro's too). | 146 → actual |

### Typos / grammar
| File:line | Issue | If ever fixed |
|-----------|-------|---------------|
| `scripts/check-surface-sync.py` L60 | `clo-author's` | → `co-author's` |
| `.claude/skills/review-paper/SKILL.md` L278 | `Edit / Edit` (duplicate tool) | → `Edit / Write` |
| `.claude/skills/triage-inbox/SKILL.md` L26 | `To handoff` (noun for verb) | → `To hand off` |
| `templates/skill-template.md` L455 | "existing skills examples" noun pile-up | → "examples of existing skills" |
| `templates/passport-template.yaml` L40 | "derives a derived quantity" | → "is a derived quantity computed from C1" |
| `.claude/rules/did-conventions.md` L55 | "His R packages" dangling pronoun | → "Sant'Anna's R packages" |
| `.claude/rules/did-conventions.md` L56 | "deliberately and documented" faulty parallelism | → "deliberately and with documentation" |
| `guide` L2209 | "Leo Yang Yang" possible doubled surname (low conf) | verify vs paper |

### Flag-doc completeness
| File:line | Issue |
|-----------|-------|
| `.claude/skills/grant-proposal/SKILL.md` L124–127 | `## Flags` omits `--out`, `--no-verify` (both in argument-hint) |
| `.claude/skills/disclosure-check/SKILL.md` L124 | `--provider` example `census-fsrdc` ≠ advertised `census` |
| `.claude/skills/review-paper/SKILL.md` L101 | flag-strip lists only 2 of ~7 flags |
| `.claude/skills/review-paper/SKILL.md` L102 | circular "(bare path from step 1)" inside step 1 |
| `.claude/references/scheduled-routines.md` L32 | `/schedule remove` may be `delete`/`run` (low conf) |
| `guide` L1056/1075/1467/1476/2288 | repo-root-relative links missing `../` prefix (low conf) |
| `.claude/skills/slide-excellence/SKILL.md` L216 | "all 6" prior-version agent count (now 7) — historical, low conf |
| `guide` L60, L857; `slide-excellence/SKILL.md` L107 | `/remote-control`, `/coarse-review`, `/configure-project` slash-refs to nonexistent/forward skills |

---

## Notes
- Origin was determined by `git grep -F <quote> upstream/main`; A4/A5 additionally confirmed by `git diff upstream/main HEAD` on `context-monitor.py` and `statusline.sh` (both diverge).
- If you later want any upstream item fixed locally anyway, it's a one-line edit each — this record has the exact target + fix.
