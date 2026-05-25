# Writing Style

**Applies to all prose Claude generates in this repository**: lecture slides (`.tex`, `.qmd`), manuscripts, README, CHANGELOG, commit messages, PR descriptions, session logs, plans, reports, and any documentation.

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

- All new prose Claude writes.
- Prose Claude edits (remove em dashes in the diff window as cleanup).
- Do NOT mass-rewrite existing em dashes across the repo as a standalone cleanup pass. Fix opportunistically.
- Code, filenames, and paths are unaffected.
- Direct quotations from external sources keep their original punctuation.
- The en dash (`–`) and hyphen (`-`) are fine for ranges (pages, dates) and compound words.

## Relationship to `/humanize`

This rule is the **always-on, generation-time** layer: it prevents em dashes from being written in the first place, across all prose Claude generates (slides, manuscripts, commits, PRs, docs).

The [`/humanize`](../skills/humanize/SKILL.md) skill is the **on-demand, review-time** layer: it audits existing prose for the broader set of AI-voice tells (boilerplate transitions, cliché lexicon, em-dash *overuse*, tricolon abuse, and more) and produces a report. The two are complementary, not redundant: keep this rule for prevention, run `/humanize` before submitting a paper to catch what slipped through.
