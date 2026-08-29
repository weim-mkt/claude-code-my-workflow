---
name: visual-audit
description: Adversarial visual-layout audit of a Quarto `.qmd` or Beamer `.tex` deck. Flags overflow, font inconsistency, box fatigue, spacing, and alignment issues. Use when user says "visual audit", "check the layout", "does this overflow?", "look for visual issues", "audit the slides", or after reworking a deck's appearance. Does NOT check writing or pedagogy — pair with `/proofread` or `/pedagogy-review`.
argument-hint: "[QMD or TEX filename]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Agent", "Task"]
disallowed-tools: ["Edit", "MultiEdit"]
---

# Visual Audit of Slide Deck

Perform a thorough visual layout audit of a slide deck.

## Steps

1. **Read the slide file** specified in `$ARGUMENTS`

2. **For Quarto (.qmd) files:**
   - Render with `quarto render Quarto/$ARGUMENTS`
   - Open in browser to inspect each slide

3. **For Beamer (.tex) files:**
   - Compile and check for overfull hbox warnings

4. **Dispatch the `slide-auditor` agent** (via the `Agent` tool — this is the
   audit itself; README, `agent-fleet.md`, and `model-routing.md` all route
   this lens to `slide-auditor` at its pinned tier, and running it inline in
   the caller's context both burns the wrong tier and skips the agent's
   checklist). Hand it the file path and rendered output. It audits every
   slide for:

   **OVERFLOW:** Content exceeding slide boundaries
   **FONT CONSISTENCY:** Inline font-size overrides, inconsistent sizes
   **BOX FATIGUE:** 2+ colored boxes on one slide, wrong box types
   **SPACING:** Missing negative margins, missing fig-align
   **LAYOUT:** Missing transitions, missing framing sentences, semantic colors

5. **Save its report** (the agent returns it inline; its grant is read-only)
   to `quality_reports/[FILE]_visual_audit.md`, organized by slide with
   severity and recommendations

6. **Recommendations follow the spacing-first principle:**
   1. Reduce vertical spacing with negative margins
   2. Consolidate lists
   3. Move displayed equations inline
   4. Reduce image/SVG size
   5. Last resort: font size reduction (never below 0.85em)
