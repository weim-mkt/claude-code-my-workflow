---
name: commit
description: Stage and commit changes locally. Stops after the commit — does NOT push, open a PR, merge, or pull unless the user explicitly asks. Use ONLY on explicit commit intent — user says "commit", "ship it", "let's commit this", or prefixes with `/commit`. Do NOT auto-invoke on vague end-of-task phrases ("we're done", "wrap up") — those require explicit confirmation first. Push/PR/merge are opt-in via separate user instruction; never force-pushes or skips hooks.
argument-hint: "[optional: commit message] [--push] [--pr] [--merge]"
allowed-tools: ["Bash", "Read", "Glob", "Agent", "Task"]
---

# Commit (with optional Push, PR, Merge)

Stage changes, verify quality gates, and commit locally. **Default scope is local commit only** — do not push, do not open a PR, do not merge, do not pull main. The user must explicitly opt in to those steps.

## Steps

### Step 0: Quality Gate (Pre-Commit)

**Run before branching.** For every changed `.qmd`, `.tex`, or `.R` file that has quality rubrics, run:

```bash
python3 scripts/quality_score.py <changed-file-paths>
```

- If any file scores below **80**, halt and report the findings. The user must either fix the issues or explicitly override with phrases like *"commit anyway"* or *"skip quality gate"*.
- If all files score 80+, continue.

Spawn the **verifier** agent (via the `Agent` tool with `subagent_type=verifier`) to run compilation/render checks on the changed files. Report pass/fail before committing.

### Step 0b: Consistency Gate (Pre-Commit)

**Runs unconditionally.** The full backtest suite — all ten gates (surface-sync count claims like `"18 agents, 60 skills, 37 rules, 8 hooks"` and marked tables, skill integrity, model currency, links, spec conformance, staleness, repo hygiene, derived counts, ledger coverage, hook battery):

```bash
./scripts/backtest.sh
```

- **Exit 0:** all gates green — continue.
- **Nonzero:** at least one gate is red — print its output and halt. Fix, then re-run. Do NOT proceed past this gate on a red result, even with "commit anyway" — count drift alone produced PRs #70, #76, and #78.

### Step 0c: Passport Check (Pre-Commit)

If the diff touches a manuscript (`.tex`/`.qmd`) that has a passport in `quality_reports/passports/`, any `source_file` a passport lists, or any file a claim declares as a display (its `location:`, or an `appears_in` `path:`), read that passport: a load-bearing claim with `status: FAIL` or `STALE` is a **must-fix** — halt, name the claim, and point at `/audit-reproducibility` (or the stale script) before committing. A touched display triggers the check for the same reason a touched script does: editing one artifact's copy of a number desynchronizes it from that number's other displays — the supplement or deck holding the same value was not necessarily updated in the same commit. Skip silently when no passport exists.

### Step 1: Check current state

```bash
git status
git diff --stat
git log --oneline -5
```

### Step 2: Create a branch

```bash
git checkout -b <short-descriptive-branch-name>
```

### Step 3: Stage files

Add specific files (never use `git add -A`):

```bash
git add <file1> <file2> ...
```

Do NOT stage `.claude/settings.local.json` or any files containing secrets.

### Step 4: Commit with a descriptive message

If `$ARGUMENTS` contains a commit message, use it. Otherwise, analyze the staged changes and write a message that explains *why*, not just *what*.

**The subject line states what is TRUE AFTER the commit** — a plain sentence about behavior that a reader could go and test. *"Fixed review feedback"* and *"Updated the checker"* narrate your afternoon and tell a reader nothing; *"The parity gate refuses a fixture whose hash is unregistered"* is a claim they can check against the code. Process narration — which review round it came from, who asked, how many attempts it took — belongs in the body if it belongs anywhere. The body still carries the *why*; the subject carries the claim.

```bash
git commit -m "$(cat <<'EOF'
<commit message here>
EOF
)"
```

### Step 5: Report and STOP

Report the new commit's hash, the branch name, and the message. **Stop here unless the user explicitly opted in to push/PR/merge** via:

- An explicit verb in the prompt: "push", "open a PR", "merge to main", "ship it to GitHub".
- A flag in `$ARGUMENTS`: `--push`, `--pr`, `--merge`.

If none of those signals are present, the workflow ends. The user can run `git push`, `gh pr create`, etc. themselves, or invoke `/commit --push` (or follow up with "now push and PR").

## Optional next steps (opt-in only)

Run these ONLY when the user explicitly asks. Do not chain them automatically.

### Step 6 (opt-in): Push branch

```bash
git push -u origin <branch-name>
```

### Step 7 (opt-in): Open PR

```bash
gh pr create --repo <user>/<repo> --base main --head <branch> --title "<short title>" --body "$(cat <<'EOF'
## Summary
<1-3 bullet points>

## Test plan
<checklist>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Step 8 (opt-in): Merge and clean up

```bash
gh pr merge <pr-number> --merge --delete-branch
git checkout main
git status --porcelain          # must print nothing before the next line runs
git pull
```

**Expect the tree to be dirty here — that is what Step 3 is for.** Staging specific files means
everything the session touched but did not stage, plus every untracked artifact, is still in the
tree when you arrive at this step. The `git-guardrails` hook this template ships **denies**
`git pull` (and `merge`, and `rebase`) whenever `git status --porcelain` is non-empty, because a
pull that resolves on top of uncommitted work cannot be reviewed afterwards — you can no longer
tell which hunk came from the remote. Chaining a stash into the same command line does not help:
the hook reads the tree, it does not predict what the line will do to it.

Clear the tree deliberately, then pull:

```bash
git stash push -u -m "post-merge: unstaged leftovers"   # -u, or untracked files stay behind
git pull
git stash pop
```

`git pull --autostash` is the one-command alternative, but only on a tree whose dirt is entirely
**tracked**. `git stash` does not stash untracked files, so an autostash over a `??` entry starts
the pull on the same dirty tree the check exists to refuse — the hook therefore reads porcelain
and **denies** `--autostash` whenever any `??` entry is present. At this step that is the usual
state, so the explicit `-u` stash above is the default route and `--autostash` is the shortcut for
the case where `git status --porcelain` shows no `??` lines at all. Git agrees independently: if
the incoming commits add a file at a path you are holding untracked, it aborts the merge
(*"untracked working tree files would be overwritten"*) after the autostash has already been
taken. Either route must be its **own** command — chaining the stash and the pull onto one line is
denied outright, because an identified history op reaches the tree reading only as a standalone
simple command.

`ALLOW_DIRTY_MERGE=1` is the hatch for a dirty state you have looked at and can justify out loud.
It is not the routine remedy, and reaching for it because the block is inconvenient is the
behavior the check exists to prevent.

### Step 9 (opt-in): Report

Report what was committed, and the PR URL if Step 7 ran.

## Important

- **Default scope is local commit only.** Pushing, opening PRs, merging, and pulling main happen ONLY when the user explicitly asks for them in the same turn. A prior `/commit` invocation does not authorize a future push.
- **Never skip Step 0.** Quality gates catch broken compilation, bad citations, and hardcoded paths before they reach `main`. If the user insists on skipping, record their override reason in the commit message.
- Always create a NEW branch — never commit directly to main.
- Exclude `settings.local.json` and sensitive files from staging.
- Use `--merge` (not `--squash` or `--rebase`) unless asked otherwise.
- When opening a PR, default to the user's fork (e.g., `gh pr create --repo <user>/<repo>`), not the upstream. `gh` defaults to the parent fork, which is usually wrong for personal-fork workflows.
- If the commit message from `$ARGUMENTS` is provided, use it exactly.
