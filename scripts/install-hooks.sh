#!/usr/bin/env bash
#
# Install the repo's version-controlled git hooks (run once per clone).
#
# Points git at `.githooks/` so `git commit` runs the pre-commit gate
# (full backtest suite + quality score). The hook lives in version control,
# so it stays in sync across machines and forks — unlike `.git/hooks/`,
# which is local and never committed.
#
set -euo pipefail

# Root from $0, not from the caller's cwd: `git rev-parse` resolves whatever
# repository the CALLER happens to stand in, which silently installs hooks
# into the wrong repo when invoked from elsewhere.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -d .githooks ]; then
    echo "install-hooks: .githooks/ not found at repo root" >&2
    exit 1
fi

chmod +x .githooks/* 2>/dev/null || true
git config core.hooksPath .githooks

echo "✓ core.hooksPath → .githooks"
echo "  Every 'git commit' now runs the full backtest suite + quality (>=80) gate."
echo "  Bypass once:  SKIP_QUALITY_GATE=1 git commit ...   (quality only)"
echo "                git commit --no-verify ...           (all hooks)"
echo "  Uninstall:    git config --unset core.hooksPath"
