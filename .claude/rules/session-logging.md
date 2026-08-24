# Session Logging

**Location:** `quality_reports/session_logs/`
**Template:** `templates/session-log.md`

Two kinds of log live here, held in separate filename namespaces by the `_auto_` marker:

| Written by | Filename | Content |
|---|---|---|
| A human, or Claude deliberately | `YYYY-MM-DD_description.md` | Narrative: goal, decisions, rationale |
| The Stop hook, automatically | `YYYY-MM-DD_auto_<topic>.md` | Mechanical: changed files, active plan, uncompiled artifacts |

The marker is load-bearing rather than decorative. `<topic>` is derived from the
active plan's description, and narrative logs get named after the same work — so
without `_auto_` the hook would append change-set dumps into prose you wrote.

`<topic>` is the newest plan in `quality_reports/plans/` not marked COMPLETED,
dated by its `YYYY-MM-DD_` filename prefix (**not** mtime, which a sync or
checkout rewrites on every plan at once) and ignored once older than 14 days — a
stale or undated plan must not name today's log as if it were current. With no
usable topic the branch name is used instead.

In a repo with more than one worktree the branch is always present
(`YYYY-MM-DD_auto_<branch>_<topic>.md`, or `..._auto_<branch>.md` with no topic),
because only then can a second tree write the same path. Git refuses to check one
branch out in two worktrees, which is what makes that field unique — a topic
cannot carry the guarantee, since a worktree inherits the main checkout's
`quality_reports/plans/` and both trees routinely compute the same one.

Implementation: [`.claude/hooks/log-reminder.py`](../hooks/log-reminder.py).

## Three Triggers (all proactive)

### 1. Post-Plan Log

After plan approval, immediately capture: goal, approach, rationale, key context.

### 2. Incremental Logging

Append 1-3 lines whenever: a design decision is made, a problem is solved, the user corrects something, or the approach changes. Do not batch.

### 3. End-of-Session Log

When wrapping up: high-level summary, quality scores, open questions, blockers.

## Quality Reports

Generated **only at merge time** -- not at every commit or PR.
Save to `quality_reports/merges/YYYY-MM-DD_[branch-name].md` using `templates/quality-report.md`.
