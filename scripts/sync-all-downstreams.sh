#!/usr/bin/env bash
#
# sync-all-downstreams.sh — fan out hop 2 of the sync chain across every registered
# downstream project.
#
# WHY THIS EXISTS
# ---------------
# `sync-from-template.sh <project>` handles ONE downstream. With a dozen research
# projects vendoring this template, running it by hand per project is exactly the cost
# the managed sync was built to remove: the per-project decisions are already recorded
# (pin + sync-exclude), so a template update should be one command, not twelve.
#
# What it will NOT do, deliberately:
#   * It never resolves anything. A project with locally-edited files, an unrecorded
#     adaptation, or conflict markers is REPORTED, never auto-fixed — the re-sync tool
#     decides nothing (release-engineering.md §4).
#   * It never overwrites uncommitted work -- and it does not need a dirty-tree test to
#     keep that promise. The report stage freezes any path whose content differs from
#     what the last sync wrote (EDITED, reported above as NEEDS DECISIONS), and the
#     apply writes only paths the report classified refresh/new/merge; a merge-mode
#     file's uncommitted local edits go INTO the 3-way merge. A `git status` test on
#     .claude/ and scripts/ (used until 2026-10-11) added no protection and skipped
#     projects for out-of-scope dirt: untracked scripts/R/*.R, a tracked
#     settings.local.json, or the previous sync's own output left uncommitted.
#   * It never stages with `git add -A`, and it commits with `git commit --only`. Only
#     the paths the sync itself touched (.git/SYNC_TOUCHED) are staged and committed, so
#     a project's unrelated in-progress work -- including changes the owner had already
#     staged before the run -- stays out of the workflow-sync commit and stays staged.
#
# Registry: ~/.claude/downstream-projects (or $DOWNSTREAM_REGISTRY) — one absolute path
# per line, '#' comments allowed. Machine-local by design: these paths differ per
# machine, so the registry is NOT committed (meta-governance.md).
#
# Usage:
#   ./scripts/sync-all-downstreams.sh                  # report every project
#   ./scripts/sync-all-downstreams.sh --apply          # apply where nothing needs a human
#   ./scripts/sync-all-downstreams.sh --apply --commit # ...and commit each applied project
#   ./scripts/sync-all-downstreams.sh --register PATH  # add a project to the registry
#
# Exit: 0 = every project clean/applied, 1 = something needs a human, 2 = could-not-run.
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)" || exit 2
SYNC="$REPO_ROOT/scripts/sync-from-template.sh"
REGISTRY="${DOWNSTREAM_REGISTRY:-$HOME/.claude/downstream-projects}"

fail() { echo "sync-all-downstreams: $1" >&2; exit "${2:-1}"; }

[ -x "$SYNC" ] || fail "sync-from-template.sh not found or not executable at $SYNC" 2

APPLY=0
COMMIT=0
while [ $# -gt 0 ]; do
    case "$1" in
        --apply)  APPLY=1 ;;
        --commit) COMMIT=1 ;;
        --register)
            shift
            [ $# -gt 0 ] || fail "--register needs a path" 2
            target="$(cd "$1" 2>/dev/null && pwd)" || fail "no such directory: $1" 2
            [ -d "$target/.claude" ] || fail "$target has no .claude/ — not a downstream" 2
            mkdir -p "$(dirname "$REGISTRY")" || exit 2
            if [ -f "$REGISTRY" ] && grep -qxF "$target" "$REGISTRY"; then
                echo "already registered: $target"
            else
                printf '%s\n' "$target" >> "$REGISTRY"
                echo "registered: $target"
            fi
            exit 0
            ;;
        *) fail "unknown argument: $1" 2 ;;
    esac
    shift
done

[ "$COMMIT" -eq 1 ] && [ "$APPLY" -eq 0 ] && fail "--commit requires --apply" 2

if [ ! -f "$REGISTRY" ]; then
    echo "sync-all-downstreams: no registry at $REGISTRY" >&2
    echo "  create it with one absolute project path per line, or:" >&2
    echo "  ./scripts/sync-all-downstreams.sh --register /path/to/project" >&2
    exit 2
fi

template_sha="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)" || fail "template is not a git repo" 2
echo "template: ${template_sha:0:12}   registry: $REGISTRY"
echo ""

rc_rollup=0
n_clean=0 n_applied=0 n_human=0 n_skip=0

while IFS= read -r line || [ -n "$line" ]; do
    proj="${line%%#*}"
    proj="$(printf '%s' "$proj" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$proj" ] && continue
    name="$(basename "$proj")"

    if [ ! -d "$proj/.claude" ]; then
        printf '  %-38s SKIP (no .claude/ at %s)\n' "$name" "$proj"
        n_skip=$((n_skip + 1)); rc_rollup=2; continue
    fi

    # Report first, always — this is what decides whether an apply is safe.
    out="$("$SYNC" "$proj" 2>&1)"; rc=$?
    counts="$(printf '%s\n' "$out" | grep -E '^   in sync:' | head -1 \
              | sed -e 's/^ *//' -e 's/  */ /g')"
    n_edit="$(printf '%s\n' "$out" | grep -c '^   EDITED ')"
    n_conf="$(printf '%s\n' "$out" | grep -c '\[CONFLICTS\]')"

    if [ "$rc" -eq 2 ]; then
        printf '  %-38s SKIP (%s)\n' "$name" "$(printf '%s\n' "$out" | tail -1)"
        n_skip=$((n_skip + 1)); rc_rollup=2; continue
    fi

    if [ "$n_edit" -gt 0 ] || [ "$n_conf" -gt 0 ]; then
        printf '  %-38s NEEDS DECISIONS (%s edited, %s conflicts)\n' "$name" "$n_edit" "$n_conf"
        n_human=$((n_human + 1)); [ "$rc_rollup" -eq 0 ] && rc_rollup=1; continue
    fi

    if [ "$rc" -eq 0 ]; then
        printf '  %-38s clean\n' "$name"
        n_clean=$((n_clean + 1)); continue
    fi

    # rc=1 with no edited/conflict lines: plain drift (refresh/new/clean merges).
    if [ "$APPLY" -eq 0 ]; then
        printf '  %-38s drift — %s\n' "$name" "${counts:-see report}"
        n_human=$((n_human + 1)); [ "$rc_rollup" -eq 0 ] && rc_rollup=1; continue
    fi

    # Applying. No dirty-tree test here: the report above already froze every locally
    # edited path (EDITED -> NEEDS DECISIONS, handled before this point), and the apply
    # writes only refresh/new/merge paths -- see the header.

    aout="$("$SYNC" "$proj" --apply 2>&1)"; arc=$?
    asum="$(printf '%s\n' "$aout" | grep -E '^applied:' | head -1)"
    if [ "$arc" -ne 0 ]; then
        printf '  %-38s APPLY INCOMPLETE (%s) — see report\n' "$name" "${asum:-rc=$arc}"
        n_human=$((n_human + 1)); [ "$rc_rollup" -eq 0 ] && rc_rollup=1; continue
    fi

    if [ "$COMMIT" -eq 0 ]; then
        printf '  %-38s applied — %s\n' "$name" "${asum#applied: }"
        n_applied=$((n_applied + 1)); continue
    fi

    touched="$proj/.git/SYNC_TOUCHED"
    if [ ! -s "$touched" ]; then
        printf '  %-38s applied, NOT committed (no touched-file list)\n' "$name"
        n_applied=$((n_applied + 1)); [ "$rc_rollup" -eq 0 ] && rc_rollup=1; continue
    fi
    if ! (cd "$proj" && xargs -I{} git add -- {} < "$touched"); then
        printf '  %-38s applied, staging FAILED\n' "$name"
        n_human=$((n_human + 1)); [ "$rc_rollup" -eq 0 ] && rc_rollup=1; continue
    fi
    # Commit ONLY the touched paths (--only): whatever the owner had staged before the
    # run stays staged and out of this commit. The pre-commit hook sees the same
    # restricted index git builds for --only.
    if (cd "$proj" && xargs git diff --quiet HEAD -- < "$touched"); then
        printf '  %-38s applied, nothing to commit\n' "$name"
        n_applied=$((n_applied + 1)); continue
    fi
    if (cd "$proj" && xargs git commit -q --only -m "workflow-sync: template ${template_sha:0:12}" -- < "$touched"); then
        printf '  %-38s applied + committed (%s)\n' "$name" \
               "$(git -C "$proj" rev-parse --short HEAD)"
        n_applied=$((n_applied + 1))
    else
        printf '  %-38s applied, COMMIT FAILED (hook or gate?)\n' "$name"
        n_human=$((n_human + 1)); [ "$rc_rollup" -eq 0 ] && rc_rollup=1
    fi
done < "$REGISTRY"

echo ""
echo "summary: $n_clean clean, $n_applied applied, $n_human need a human, $n_skip skipped"
exit "$rc_rollup"
