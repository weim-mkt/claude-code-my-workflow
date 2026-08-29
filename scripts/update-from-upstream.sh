#!/usr/bin/env bash
#
# update-from-upstream.sh — hop 1 of the sync chain: upstream (pedrohcgs) -> this fork.
#
# WHY THIS EXISTS
# ---------------
# This fork's main is a PATCH QUEUE rebased onto upstream/main and pushed with
# --force-with-lease. Done by hand across two machines, the ritual has two recorded
# failure modes this script checks mechanically instead of by habit:
#
#   * Multi-machine clobber: rebasing on machine A while machine B holds unpushed
#     commits strands B's work. Guard: origin/main must equal the local tip EXACTLY
#     before rebasing (a mere "not ahead" check renews the force-with-lease lease and
#     can still clobber the other machine's just-pushed work).
#   * Silent rerere replays and modify/delete collisions: rerere re-applies old
#     resolutions textually and records nothing for delete/rename conflicts. Guard:
#     collisions between the patch queue's touched files and upstream's changed or
#     deleted paths are listed BEFORE the rebase; replayed resolutions are listed after.
#
# Nothing is pushed unless the full backtest gate suite AND the sync-script selftest
# are green — hop 1 must never ship a broken template (or a broken sync tool) to the
# downstream projects that pull from it.
#
# Usage: ./scripts/update-from-upstream.sh          (run from anywhere; root is $0-derived)
# Exit:  0 = updated + pushed (or already current), 1 = stopped for a human, 2 = could-not-run.
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)" || exit 2
cd "$REPO_ROOT" || exit 2

fail() { echo "update-from-upstream: $1" >&2; exit "${2:-1}"; }

# ---- preconditions ----------------------------------------------------------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a git repo" 2
git remote get-url upstream >/dev/null 2>&1 || fail "no 'upstream' remote configured" 2
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || fail "not on main — check it out first"
gitdir="$(git rev-parse --git-dir)"
[ -d "$gitdir/rebase-merge" ] || [ -d "$gitdir/rebase-apply" ] \
    && fail "a rebase is already in progress — finish or abort it first"
# tracked changes only (-uno): untracked files can't corrupt a rebase — git refuses
# safely if an incoming commit collides with one — and this repo routinely has them.
[ -z "$(git status --porcelain -uno)" ] || fail "working tree has uncommitted tracked changes — commit or stash first"
n_wt="$(git worktree list --porcelain | grep -c '^worktree ')"
[ "$n_wt" -eq 1 ] || fail "extra worktrees exist ($n_wt) — remove them before rebasing main"

echo "── fetching origin + upstream ──"
git fetch origin || fail "fetch origin failed" 2
git fetch upstream || fail "fetch upstream failed" 2

# ---- serial-machine guard: origin/main must equal the local tip EXACTLY -----
local_tip="$(git rev-parse main)"
origin_tip="$(git rev-parse origin/main 2>/dev/null)" || fail "no origin/main" 2
if [ "$local_tip" != "$origin_tip" ]; then
    fail "origin/main ($(git rev-parse --short origin/main)) != local main \
($(git rev-parse --short main)). Another machine pushed, or you have unpushed commits. \
Reconcile first (pull/rebase onto origin/main, or push), then re-run."
fi

if [ "$(git rev-parse upstream/main)" = "$(git merge-base main upstream/main)" ]; then
    echo "already up to date with upstream/main — nothing to do."
    exit 0
fi

# ---- pre-rebase collision preview ------------------------------------------
base="$(git merge-base main upstream/main)"
queue_files="$(git log --format= --name-only "$base"..main | sort -u | sed '/^$/d')"
upstream_changes="$(git diff --name-status "$base" upstream/main)"
collisions="$(echo "$upstream_changes" | awk '{print $NF"\t"$1}' | sort \
    | join -t $'\t' - <(echo "$queue_files") 2>/dev/null || true)"
echo "── incoming: $(git rev-list --count "$base"..upstream/main) upstream commit(s); \
patch queue: $(git rev-list --count "$base"..main) commit(s) ──"
if [ -n "$collisions" ]; then
    echo "!! files touched by BOTH the patch queue and upstream (D = upstream deleted it,"
    echo "!! a class rerere cannot record — expect these in the rebase):"
    echo "$collisions" | sed 's/^/     /'
fi

# ---- rebase -----------------------------------------------------------------
rebase_log="$(mktemp)"
if ! git rebase upstream/main >"$rebase_log" 2>&1; then
    cat "$rebase_log"
    echo ""
    fail "rebase stopped on conflicts — resolve, 'git rebase --continue', then re-run \
this script (it will verify and push). 'git rebase --abort' restores the previous state."
fi
replayed="$(grep -c 'using previous resolution' "$rebase_log" || true)"
cat "$rebase_log"; rm -f "$rebase_log"
if [ "${replayed:-0}" -gt 0 ]; then
    echo "!! rerere replayed $replayed recorded resolution(s) — review them before pushing:"
    echo "!!   git diff origin/main..HEAD -- <the files above>"
fi

# ---- gates ------------------------------------------------------------------
echo "── backtest gate suite ──"
./scripts/backtest.sh || fail "backtest FAILED after rebase — fix before pushing"
echo "── sync-script selftest ──"
./scripts/sync-from-template.sh --selftest || fail "sync-from-template selftest FAILED"

if ! git diff --quiet "$base" HEAD -- guide/workflow-guide.qmd 2>/dev/null; then
    echo "note: guide/workflow-guide.qmd changed in this update — if the rebase left it"
    echo "      ahead of its render, re-render + ./scripts/stamp-render.sh before pushing"
    echo "      (check-staleness inside backtest will have said so if required)."
fi

# ---- push -------------------------------------------------------------------
echo "── pushing (--force-with-lease) ──"
git push --force-with-lease origin main || fail "push failed (lease stale? re-run)"
echo "update-from-upstream: done — main is $(git rev-parse --short HEAD), gates green, pushed."
