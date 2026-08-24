#!/usr/bin/env bash
# Per-clone setup for this fork. Run once after cloning, on every machine.
#
# WHY THIS EXISTS
# ---------------
# `main` is maintained as a PATCH QUEUE: upstream/main, plus a short series of
# named `fork:` commits replayed on top of it at every sync. Two pieces of that
# workflow live in `.git/config`, which git does not track — so a fresh clone
# silently lacks them and the next sync is needlessly painful. This script is
# the one command that installs them.
#
# It is idempotent: run it as often as you like.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== fork setup =="

# 1. rerere — "reuse recorded resolution".
#    Every fork patch that touches a file upstream also edits will conflict
#    again on the next rebase, in exactly the same way. rerere records how you
#    resolved it and replays that resolution automatically next time. Without
#    it you re-resolve the same conflicts by hand at every release.
git config rerere.enabled true
git config rerere.autoupdate true
echo "  rerere:            enabled (autoupdate on)"

# 2. The keep-ours merge driver, referenced by .gitattributes for docs/*.html
#    and guide/*.html. Those are Quarto build outputs of
#    guide/workflow-guide.qmd; a conflict in them carries no intent, because
#    the correct content is whatever `quarto render` produces from the merged
#    source. `true` is a no-op driver: it exits 0 and leaves our copy in place,
#    so the merge never stops. The re-render immediately afterwards is what
#    makes the content right, and stamp-render.sh is what proves it did.
git config merge.keep-ours.driver true
echo "  keep-ours driver:  installed (see .gitattributes)"

# 3. The pre-commit gate — surface-sync + quality (>=80) + the backtest suite.
if [ -x ./scripts/install-hooks.sh ]; then
    ./scripts/install-hooks.sh >/dev/null 2>&1 \
        && echo "  pre-commit hooks:  installed" \
        || echo "  pre-commit hooks:  install-hooks.sh failed — run it manually"
else
    echo "  pre-commit hooks:  scripts/install-hooks.sh not found or not executable"
fi

cat <<'NOTE'

== the sync ritual ==

  git fetch upstream
  git rebase upstream/main        # rerere replays known conflicts, patch by patch

  # if guide/workflow-guide.qmd moved, refresh the artifact patch (kept last):
  ( cd guide && quarto render workflow-guide.qmd )
  cp guide/workflow-guide.html docs/workflow-guide.html
  ./scripts/stamp-render.sh
  git commit --amend --no-edit

  ./scripts/backtest.sh           # all ten gates must be green
  git push --force-with-lease origin main

Machines are assumed SERIAL: one at a time, always pushed before switching.
On any other machine, next time you sit down:  git fetch && git reset --hard origin/main
NOTE
