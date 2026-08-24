---
paths:
  - "Slides/**/*.tex"
  - "Quarto/**/*.qmd"
  - "docs/**"
---

# Task Completion Verification Protocol

**Before reporting a slide or deck task done, confirm the output builds and renders** — a deck that compiles with a missing figure or an overflowing slide is not done, and the user usually discovers it in front of a class.

## For Quarto/HTML Slides:
1. Run `./scripts/sync_to_docs.sh` (or `./scripts/sync_to_docs.sh LectureN`) to render and deploy
2. Measure the render: `"${SLIDE_QA_PYTHON:-python3}" scripts/slide-qa.py Quarto/LectureN.html` loads the deck in headless Chrome and writes `quality_reports/audits/slide-qa/LectureN/report.md` plus one `slide-NN.png` screenshot per slide. Read the report and the screenshots of flagged and dense slides. If it exits 2 (it could not run, usually because Playwright is missing; see `TROUBLESHOOTING.md`), read the rendered HTML of the dense slides instead, Read any screenshot or PDF export the user supplies, and name the slides the user should eyeball — `open` launches a window only the user can see
3. Verify images display by reading 2-3 image files to confirm valid content
4. Check HTML source for correct image paths
5. Take overflow from the slide-qa report (exit 1 flags overflow, clipped content, or a broken or wrong-case asset). If slide-qa could not run, scan the dense slides in the source and say that overflow was judged from the source
6. Verify environment parity: every Beamer box environment has a CSS equivalent in the QMD
7. Report verification results

## For LaTeX/Beamer Slides:
1. Compile with xelatex and check for errors
2. Read the compiled PDF pages that carry figures to confirm they render
3. Check for overfull hbox warnings

## For TikZ Diagrams in HTML/Quarto:
1. Browsers **cannot** display PDF images inline — ALWAYS convert to SVG
2. Use SVG (vector format) for crisp rendering: `pdf2svg input.pdf output.svg`
3. **NEVER use PNG for diagrams** — PNG is raster and looks blurry
4. Verify SVG files contain valid XML/SVG markup
5. Copy SVGs to `docs/Figures/LectureX/` via `sync_to_docs.sh`
6. **Freshness check:** Before using any TikZ SVG, verify extract_tikz.tex matches current Beamer source

## For R Scripts:
1. Run `Rscript scripts/R/filename.R`
2. Verify output files (PDF, fst, qs2) were created with non-zero size
3. Spot-check estimates for reasonable magnitude

## Claims About Code Carry a Revision:

Any statement about what the code currently does carries the revision it was read at — the full standard lives in [`agent-authored-code.md`](agent-authored-code.md), which loads whenever a `.sh`/`.py`/`.R`/`.do` file is touched (this rule is scoped to slide/HTML deliverables, so the obligation belongs where code work actually happens).

## Common Pitfalls:
- **PDF images in HTML**: Browsers don't render PDFs inline → convert to SVG
- **Relative paths**: `../Figures/` works from `Quarto/` but not from `docs/slides/` → use `sync_to_docs.sh`
- **Assuming success**: Always verify output files exist AND contain correct content
- **Stale TikZ SVGs**: extract_tikz.tex diverges from Beamer source → always diff-check

## Verification Checklist:
```
[ ] Output file created successfully
[ ] No compilation/render errors
[ ] Images/figures display correctly
[ ] Paths resolve in deployment location (docs/)
[ ] Rendered output inspected, or the slides to eyeball named for the user
[ ] Any claim about code state carries the revision it was read at
[ ] Reported results to user
```
