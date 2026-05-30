# Writing Style

**Applies to production prose only**: prose that ships to a reader or an external service. The rule is *not* enforced on internal working files. See [Scope](#scope) for the exact split.

## Rule: No em dashes

Do **not** use em dashes (`—`, U+2014) in written prose.

**Why:** Em dashes are a stylistic tell of AI-generated text. The user wants prose that does not read as machine-written.

**How to apply:** Whenever you would reach for `—`, choose one of:

| Instead of em dash | Use |
|---|---|
| Parenthetical aside | comma pair, or parentheses `( )` |
| Sharp break / emphasis | period + new sentence |
| List-like elaboration | colon `:` |

### Examples

| Avoid | Prefer |
|---|---|
| "The method — first proposed by Angrist — uses IV." | "The method, first proposed by Angrist, uses IV." |
| "It works — but only under assumption A." | "It works, but only under assumption A." |
| "Three goals — clarity, rigor, brevity." | "Three goals: clarity, rigor, brevity." |

## Scope

The rule targets **production prose**: text that an audience or an external system will read. It is *not* enforced on internal working files that only you and Claude read.

### Enforced (production / audience-facing)

- Lecture slides: Beamer `.tex` and Quarto `.qmd` content.
- Manuscripts and papers, including Overleaf LaTeX (`.tex`) sources.
- Any deliverable rendered for an external audience (exported PDFs, published HTML, the GitHub Pages site).

### Not enforced (internal working files)

- Session logs, plans, specs, quality reports, decision records (`quality_reports/**`).
- Commit messages and PR descriptions.
- `MEMORY.md`, `.claude/state/personal-memory.md`, and other notes-to-self.
- Scratch / sandbox files under `explorations/`.

Em dashes in these are fine. Don't spend effort removing them, and don't let a review flag them.

> Repo docs (`README`, `CHANGELOG`, `guide/`, the landing page) are a judgment call: they are public-facing, so prefer the rule there, but they are not hard-enforced. The hard line is academic deliverables and Overleaf sources on the production side, working notes on the internal side.

### General

- Applies to new production prose Claude writes, and to production prose Claude edits (remove em dashes in the diff window as cleanup).
- Do NOT mass-rewrite existing em dashes across the repo as a standalone cleanup pass. Fix opportunistically, and only in enforced files.
- Code, filenames, and paths are unaffected.
- Direct quotations from external sources keep their original punctuation.
- The en dash (`–`) and hyphen (`-`) are fine for ranges (pages, dates) and compound words.

## Relationship to `/humanize`

This rule is the **always-on, generation-time** layer: it prevents em dashes from being written in the first place, in production prose (slides, manuscripts, Overleaf sources). It does not police internal working files.

The [`/humanize`](../skills/humanize/SKILL.md) skill is the **on-demand, review-time** layer: it audits existing prose for the broader set of AI-voice tells (boilerplate transitions, cliché lexicon, em-dash *overuse*, tricolon abuse, and more) and produces a report. The two are complementary, not redundant: keep this rule for prevention, run `/humanize` before submitting a paper to catch what slipped through.
