---
paths:
  - "scripts/**/*.R"
  - "explorations/**"
  - "Figures/**/*.R"
---

# Research Project Orchestrator (Simplified)

**For R scripts, simulations, and data analysis** -- use this simplified loop instead of the full multi-agent orchestrator.

## The Simple Loop

```
R / analysis task (user-requested)
  │
  Step 1: IMPLEMENT — Execute plan steps
  │
  Step 2: VERIFY — Run code, check outputs
  │         R scripts: Rscript runs without error
  │         Simulations: set.seed reproducibility
  │         Plots: PDF/PNG created, correct format
  │         If verification fails → fix → re-verify
  │
  Step 3: SCORE — Apply quality-gates rubric
  │
  └── Score >= 80?
        YES → Done (commit when user signals)
        NO  → Fix blocking issues, re-verify, re-score
```

**One agent, no review fan-out:** write, run, verify, score. Reach for the fan-out runtime in `orchestrator-protocol.md` only through a skill that invokes it (e.g. `/review-r`, `/simulation-study`).

## Verification Checklist

- [ ] Script runs without errors
- [ ] All packages loaded at top
- [ ] No hardcoded absolute paths
- [ ] `set.seed(888)` before each randomness step
- [ ] Output files created at expected paths
- [ ] Tolerance checks pass (if applicable)
- [ ] Quality score >= 80
