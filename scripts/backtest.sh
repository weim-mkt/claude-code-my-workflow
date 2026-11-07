#!/usr/bin/env bash
# backtest.sh — prove the whole repo is internally consistent and currently true.
#
# Run this after ANY change. It is the difference between a maintained repo and
# one that merely looks maintained. Eleven gates:
#
#   1. surface-sync        counts + enumerative tables match what is on disk
#   2. skill-integrity     frontmatter <-> body tool parity, anchors, flag parity
#   3. model-versions      no superseded model presented as current (internal
#                         consistency against the model SSoT; the EXPIRY on that
#                         SSoT is enforced by gate 6, staleness)
#   4. links               every relative link and heading anchor resolves
#   5. spec-conformance    every skill obeys the Agent Skills spec
#   6. staleness           stale recommendations, source/render divergence, expired currency
#   7. repo-hygiene       no scratch-as-main, no root clutter, archives documented
#   8. derived-counts     enumerable claims (journals, patterns, phases, snippets)
#                         verified against their own source of truth
#   9. ledger-coverage    the qualification ledger and the checks that actually run
#                         agree in BOTH directions, and every hook in settings.json
#                         is wired to a file that exists (a mistyped path there
#                         disables a hook in silence)
#  10. hook-battery       the active guard hooks are driven with synthetic events
#                         and must still go red on the failure each one targets —
#                         gate 9 proves a hook is wired, this proves it still acts
#  11. portability        path, encoding, line-ending and git-output cases that
#                         differ on other machines — Windows simulated through
#                         ntpath (tests/portability/), each pinning a real defect
#   +  findings-validator  smoke test, so a review run cannot fail at the last step
#
# Every gate runs to completion even if an earlier one fails — you get the whole
# picture in one pass. Exit code is the max of all gates.
#
# TEMPLATE vs DOWNSTREAM. Four of the eleven gates check surfaces only the template
# repo carries (README.md, guide/, docs/, CHANGELOG.md, the qualification ledger).
# A downstream project that vendors .claude/ + scripts/ via sync-from-template.sh gets this
# script too, and running it there used to emit "surface file missing" errors that
# look like defects but only mean the gate is inapplicable. So the suite detects
# which repo it is in and, in a downstream, runs the gates that DO apply while
# labelling the rest N/A. Force either mode with BACKTEST_MODE=template|downstream.
#
# No `set -e`: it would abort after the first failure and hide the rest.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
    echo "backtest: cannot resolve script directory" >&2; exit 2
fi

ROOT="$(cd "$DIR/.." 2>/dev/null && pwd)" || exit 2

# Template identity: the self-documenting surfaces the template-only gates read.
MODE="${BACKTEST_MODE:-}"
if [ -z "$MODE" ]; then
    if [ -f "$ROOT/CHANGELOG.md" ] && [ -f "$ROOT/README.md" ] && [ -d "$ROOT/guide" ]; then
        MODE=template
    else
        MODE=downstream
    fi
fi

RC=0
run() {  # run <label> <command...>
    local label="$1"; shift
    echo ""
    echo "── $label ──"
    "$@"
    local rc=$?
    [ "$rc" -gt "$RC" ] && RC=$rc
    return 0
}

skip() {  # skip <label> <why>
    echo ""
    echo "── $1 ──"
    echo "N/A in a downstream project: $2"
}

echo "═══ BACKTEST: is this repo internally consistent and currently true? ═══"
[ "$MODE" = downstream ] && echo "(downstream mode — template-only gates reported N/A)"

if [ "$MODE" = template ]; then
    run "surface-sync"   python3 "$DIR/check-surface-sync.py"
else
    skip "surface-sync"  "reads README.md / guide/ / docs/, which this repo does not carry"
fi
run "skill-integrity"    python3 "$DIR/check-skill-integrity.py"
if [ "$MODE" = template ]; then
    run "model-versions" "$DIR/check-model-versions.sh"
else
    skip "model-versions" "checks the template's own README/guide model claims"
fi
run "links"              python3 "$DIR/check-links.py"
run "spec-conformance"   python3 "$DIR/check-spec-conformance.py"
run "staleness"          python3 "$DIR/check-staleness.py"
run "repo-hygiene"       python3 "$DIR/check-repo-hygiene.py"
if [ "$MODE" = template ]; then
    run "derived-counts"  python3 "$DIR/check-derived-counts.py"
    run "ledger-coverage" python3 "$DIR/check-ledger-coverage.py"
else
    skip "derived-counts"  "verifies counts claimed in the template's README/guide"
    skip "ledger-coverage" "audits the template's own qualification ledger"
fi
run "hook-battery"       bash "$DIR/hook-battery.sh"
run "portability"        python3 "$DIR/portability-tests.py"

echo ""
echo "── findings-validator smoke test ──"
echo '[]' | python3 "$DIR/validate-findings.py"
rc=$?; [ "$rc" -gt "$RC" ] && RC=$rc

echo ""
if [ "$RC" -eq 0 ]; then
    echo "═══ BACKTEST PASSED — repo is fresh and internally consistent ═══"
else
    echo "═══ BACKTEST FAILED (exit $RC) — fix before shipping ═══"
fi
exit "$RC"
