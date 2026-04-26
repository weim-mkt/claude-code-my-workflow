---
name: commit
description: Stage and commit changes locally. Stops after the commit — does NOT push, open a PR, merge, or pull unless the user explicitly asks. Use ONLY on explicit commit intent — user says "commit", "ship it", "let's commit this", or prefixes with `/commit`. Do NOT auto-invoke on vague end-of-task phrases ("we're done", "wrap up") — those require explicit confirmation first. Push/PR/merge are opt-in via separate user instruction; never force-pushes or skips hooks.
argument-hint: "[optional: commit message] [--push] [--pr] [--merge]"
allowed-tools: ["Bash", "Read", "Glob", "Task"]
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

Spawn the **verifier** agent (via `Task` with `subagent_type=verifier`) to run compilation/render checks on the changed files. Report pass/fail before committing.

### Step 0b: Surface-Sync Gate (Pre-Commit)

**Runs unconditionally.** Enforces that count claims (`"14 agents, 28 skills, 24 rules, 6 hooks"` and siblings) across README.md, CLAUDE.md, the guide source + rendered HTML, the landing page, and the skill template all agree with the on-disk counts of `.claude/{skills,agents,rules,hooks}`:

```bash
./scripts/check-surface-sync.sh
```

- **Exit 0:** all counts consistent — continue.
- **Exit 1:** drift detected — print the diff and halt. Fix the stale counts, then re-run. Do NOT proceed past this gate on drift, even with "commit anyway" — the purpose is to catch the exact class of issue that produced PRs #70, #76, and #78.
- **Exit 2:** script error (missing surface file, unreadable directory) — investigate before proceeding.

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
git pull
```

## Important

- **Default scope is local commit only.** Pushing, opening PRs, merging, and pulling main happen ONLY when the user explicitly asks for them in the same turn. A prior `/commit` invocation does not authorize a future push.
- **Never skip Step 0.** Quality gates catch broken compilation, bad citations, and hardcoded paths before they reach `main`. If the user insists on skipping, record their override reason in the commit message.
- Always create a NEW branch — never commit directly to main.
- Exclude `settings.local.json` and sensitive files from staging.
- Use `--merge` (not `--squash` or `--rebase`) unless asked otherwise.
- When opening a PR, default to the user's fork (e.g., `gh pr create --repo <user>/<repo>`), not the upstream. `gh` defaults to the parent fork, which is usually wrong for personal-fork workflows.
- If the commit message from `$ARGUMENTS` is provided, use it exactly.
