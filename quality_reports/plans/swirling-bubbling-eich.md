# Plan: Adapt Repository for Wei Miao @ UCL School of Management

**Status:** DRAFT
**Date:** 2026-03-21

---

## Context

This repo was forked from Pedro H. C. Sant'Anna's Econ 730 workflow at Emory. Wei Miao needs to personalize it for UCL School of Management. The infrastructure (agents, skills, rules, hooks) is domain-agnostic — only identity, branding, and course-specific content need changing.

## User Decisions

- **Project name in CLAUDE.md:** Keep generic (placeholders stay)
- **Colors:** Switch to UCL brand colors
- **Pedro's artifacts:** Keep as examples
- **Econ 730 case study:** Remove from guide

---

## Step 1: Identity Updates

### LICENSE (line 3)
- `Pedro H. C. Sant'Anna` → `Wei Miao`

### guide/workflow-guide.qmd (lines 4-5)
- `author: "Pedro H. C. Sant'Anna"` → `author: "Wei Miao"`
- `date: "2026-03-20"` → `date: "2026-03-21"`

### README.md
- **Line 5:** Replace `psantanna.com/claude-code-my-workflow` link → point to Wei's GitHub Pages (e.g., `weimiao.github.io/claude-code-my-workflow` or remove line)
- **Line 6:** Update date to 2026-03-21
- **Lines 30, 32, 36, 79, 276:** Replace all `psantanna.com` URLs with correct GitHub Pages URL
- **Line 260:** Rewrite origin paragraph — remove Pedro/Emory/Econ 730 specifics, keep as "forked from a production academic workflow" with link to original repo

---

## Step 2: Remove Econ 730 Case Study from Guide

### guide/workflow-guide.qmd — sections to remove/rewrite:
- **Line 63:** `## Case Study: Econ 730 at Emory` — remove entire section (lines ~63-68)
- **Line 421:** Econ 730 Lecture 6 critic example — replace with generic description of what the QA loop does (no course-specific details)
- **Line 463:** Econ 730 verification example — replace with generic "verification catches..." description
- **Line 468:** Domain reviewer Econ 730 example — keep the concept but replace with a generic field example or placeholder
- **Lines 514-515:** `Econ 730 / Emory University` in CLAUDE.md example → use `[YOUR PROJECT NAME]` / `[YOUR INSTITUTION]` placeholders
- **Line 1912:** `ECN 152 course development, Econ 730 causal panel data` — remove or generalize
- **Line 2380:** Origin story — rewrite as "Originally extracted from a production PhD course" with link to Pedro's repo

---

## Step 3: UCL Color Theme

### guide/custom.scss
- **Line 3 comment:** `Emory Navy & Gold` → `UCL Brand Colors`
- **Lines 4-7:** Replace color variables:
  - `$navy: #012169` → UCL Dark Blue `#002855` (or official UCL Indigo)
  - `$gold: #B9975B` → UCL accent (need to confirm — options: UCL Mid Green #8DB600, or a warm accent)
  - `$navy-light` and `$gold-pale` — derive from new primaries
- **Line 141:** Update `rgba(185, 151, 91, 0.08)` inline code bg to match new accent
- **Line 18:** Update `$code-color: #8b6914` to match new accent

**Note:** Need to look up official UCL School of Management brand colors. Will web search during implementation.

---

## Step 4: Save User Memory

Save a memory file noting Wei Miao's identity (UCL School of Management) for future sessions.

---

## Step 5: Re-render & Verify

1. `quarto render guide/workflow-guide.qmd` — regenerate HTML with new author, colors, content
2. `./scripts/sync_to_docs.sh` — update docs/ for GitHub Pages
3. Visual check that colors look right
4. Confirm no remaining Pedro/Emory references in rendered output (grep)

---

## Files Modified

| File | Change Type |
|------|------------|
| `LICENSE` | Author name |
| `README.md` | URLs, date, origin story |
| `guide/workflow-guide.qmd` | Author, date, remove case study, generalize examples |
| `guide/custom.scss` | UCL colors |

## Files NOT Modified

- `CLAUDE.md` — keep placeholders (user decision)
- `.claude/` agents, skills, rules, hooks — all generic
- `quality_reports/` existing artifacts — keep as examples (user decision)
- `MEMORY.md` — generic learnings, still useful
- `templates/` — all domain-agnostic

---

## Verification

- [ ] `grep -ri "pedro\|emory\|econ 730\|psantanna" guide/ README.md LICENSE` returns no hits (except quoted origin link)
- [ ] Guide renders without errors
- [ ] UCL colors display correctly in rendered guide
- [ ] docs/ updated with fresh HTML
- [ ] No broken links in README
