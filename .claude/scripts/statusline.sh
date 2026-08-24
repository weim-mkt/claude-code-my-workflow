#!/usr/bin/env bash
# Claude Code status line: shows model, git branch, plan status, and context usage.
#
# Claude Code pipes a JSON session snapshot to stdin. Relevant keys:
#   .model.display_name                e.g. "Opus <version>"
#   .workspace.current_dir             absolute path of the cwd
#   .context_window.used_percentage    live context-window usage (0-100)
#
# Note: the live permission mode is NOT part of the statusline JSON contract, so it
# cannot be shown here. Claude Code's input box shows the current mode instead.

set -euo pipefail

INPUT="$(cat)"

# Parse all fields in a single python3 invocation. Status line renders on every
# turn; avoid multiple forks when one suffices.
parsed="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print((d.get('model') or {}).get('display_name', '?'))
print((d.get('workspace') or {}).get('current_dir', '.'))
print((d.get('context_window') or {}).get('used_percentage') or '')
" 2>/dev/null || printf '?\n\n\n')"

model="$(printf '%s' "$parsed" | sed -n '1p')"
cwd="$(printf '%s' "$parsed" | sed -n '2p')"
pct="$(printf '%s' "$parsed" | sed -n '3p')"
[ -n "$model" ] || model="?"
[ -n "$cwd" ] && [ "$cwd" != "." ] || cwd="$(pwd)"

# Optional enrichment (branch, dirty count, plan status, context %).
# Wrapped in `set +e` so a probe failure can never blank the status line.
set +e
branch=""
dirty=""
if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch="$(git -C "$cwd" branch --show-current 2>/dev/null)"
    n="$(git -C "$cwd" status --porcelain 2>/dev/null | grep -c '.')"
    [ "${n:-0}" -gt 0 ] 2>/dev/null && dirty="±${n}"
fi

# Most-recent plan's status (DRAFT / APPROVED / COMPLETED).
plan_badge=""
latest_plan="$(ls -t "$cwd"/quality_reports/plans/*.md 2>/dev/null | head -1)"
if [ -n "$latest_plan" ]; then
    if   grep -qi 'COMPLETED' "$latest_plan" 2>/dev/null; then plan_badge="plan:done"
    elif grep -qi 'APPROVED'  "$latest_plan" 2>/dev/null; then plan_badge="plan:approved"
    elif grep -qi 'DRAFT'     "$latest_plan" 2>/dev/null; then plan_badge="plan:DRAFT"
    fi
fi

# Context % — read straight from context_window.used_percentage, the field Claude
# Code pipes in on stdin (added v2.1.132). Exact (uses the real window size),
# always live, and resets after /compact. No transcript parsing or hook-written
# file needed; context-monitor.py still derives its own % for the nudge thresholds.
ctx=""
[ -n "$pct" ] && ctx="ctx $(printf '%.0f' "$pct" 2>/dev/null)%"
set -e

line="$model"
[ -n "$branch" ] && line="$line  @ $branch"
[ -n "$dirty" ] && line="$line $dirty"
[ -n "$plan_badge" ] && line="$line  $plan_badge"
[ -n "$ctx" ] && line="$line  $ctx"

printf '%s' "$line"
