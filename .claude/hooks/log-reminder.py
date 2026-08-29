#!/usr/bin/env python3
"""
Session-Log Auto-Writer Hook (Stop)

A Stop hook that **writes** the session log instead of nagging about it.
The previous version (v1.x) only emitted stderr advisories — "consider
updating the log" — and left the writing to the human/agent. The modern
posture is: the system does the bookkeeping, you do the research.

On each Stop, when the working tree has changed since the last auto-entry,
it appends a structured entry to today's session log
(quality_reports/session_logs/YYYY-MM-DD_auto_BRANCH.md, created if absent):

  - timestamp
  - changed files (git status --porcelain, capped)
  - active plan + status (most recent non-completed plan)
  - compile-completion note: any Slides/*.tex or Quarto/*.qmd newer than
    its compiled output (.pdf / .html). Non-blocking by default; set
    CLAUDE_COMPILE_GATE=block to turn the note into a Stop-block that asks
    Claude to compile before stopping.

Filename: `YYYY-MM-DD_auto_<topic>.md`, where <topic> comes from the active plan
(`2026-07-19_auto_b1-sample-window-rerun.md`) so the log says what the session was
*about*. In a repo with more than one worktree the branch is inserted —
`2026-07-19_auto_revision-within-iphone-att_b1-sample-window-rerun.md` — because
only then can a second tree collide, and the branch is the field git guarantees
is unique. Without it a main checkout and a worktree write the same tracked path
and their divergent logs conflict on merge. Entries also carry a short session id,
so two sessions sharing one file stay attributable.

Throttling: writes only when `git status --porcelain` changed since the
last entry (hashed in state), so a quiet turn does not spam the log.

Fail-open: any error → exit 0, never blocks Claude on a hook bug.

Usage (.claude/settings.json):
    "Stop": [{ "hooks": [{ "type": "command",
      "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/log-reminder.py" }] }]
"""

from __future__ import annotations

import json
import os
import sys
import hashlib
import re
import subprocess
from pathlib import Path
from datetime import datetime


def get_state_dir() -> Path:
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project_dir:
        d = Path.home() / ".claude" / "sessions" / "default"
    else:
        h = hashlib.md5(project_dir.encode()).hexdigest()[:8]
        d = Path.home() / ".claude" / "sessions" / h
    d.mkdir(parents=True, exist_ok=True)
    return d


def _git(project_dir: str, *args: str) -> str | None:
    """None = git did NOT answer (missing binary, non-zero exit, timeout).
    A real empty string is a real answer — e.g. a genuinely clean tree.
    Collapsing the two made a slow or broken git read as "clean", and a
    dirty session ended with no log written."""
    try:
        out = subprocess.run(
            ["git", "-C", project_dir, *args],
            capture_output=True, text=True, timeout=5,
        )
        return out.stdout if out.returncode == 0 else None
    except Exception:
        return None


def _slugify(text: str) -> str:
    """Filesystem-safe slug. Underscore is NOT preserved — it is the reserved
    field separator in the log filename (see `log_basename`)."""
    # Flatten `revision/within-iphone-att` → `revision-within-iphone-att`; a raw
    # slash would silently redirect the log into a nonexistent subdirectory.
    slug = re.sub(r"[^A-Za-z0-9.-]+", "-", text).strip("-.")
    slug = re.sub(r"-{2,}", "-", slug)
    if len(slug) > 40:
        # Bare truncation maps `…-pipeline-part-1` and `…-pipeline-part-2` onto one
        # name — reintroducing the collision this whole scheme exists to prevent.
        # Keep a digest of the full text so long names stay distinct.
        slug = slug[:33].strip("-.") + "-" + hashlib.md5(text.encode()).hexdigest()[:6]
    return slug.strip("-.")


def branch_slug(project_dir: str) -> str:
    """Slug for the branch checked out in `project_dir`.

    Read from the same directory the status came from, so the slug always
    describes that tree. Git refuses to check one branch out in two worktrees,
    which is what makes this the collision-free part of the filename.
    """
    ref = (_git(project_dir, "rev-parse", "--abbrev-ref", "HEAD") or "").strip()
    if ref in ("", "HEAD"):  # detached HEAD (or git unanswered) — fall back to the sha
        sha = (_git(project_dir, "rev-parse", "--short", "HEAD") or "").strip()
        ref = f"detached-{sha}" if sha else "nogit"
    return _slugify(ref) or "nogit"


TOPIC_STALE_DAYS = 14


def topic_slug(project_dir: str) -> str:
    """Topic for the filename, taken from the active plan's description.

    `quality_reports/plans/2026-07-18_b1-sample-window-rerun.md` →
    `b1-sample-window-rerun`. This is what makes a log say what the session was
    *about* rather than merely which branch it ran on.

    A plan only counts if it is newer than TOPIC_STALE_DAYS. `active_plan` selects
    the newest plan not marked COMPLETED, and a plan abandoned months ago without
    that marker still qualifies — naming today's log after it would be worse than
    a bland name, because it reads as fact. Returns "" when stale, and the caller
    falls back to the branch.
    """
    p = _active_plan_file(project_dir)
    if p is None:
        return ""
    if (datetime.now().timestamp() - _plan_ts(p)) / 86400 > TOPIC_STALE_DAYS:
        return ""
    # Drop the leading YYYY-MM-DD_ and the .md — keep the human-written part.
    return _slugify(re.sub(r"^\d{4}-\d{2}-\d{2}[_-]?", "", p.stem))


def worktree_count(project_dir: str) -> int:
    """How many worktrees this repo has. Both the main checkout and a linked
    worktree report the same number, so every tree reaches the same decision."""
    out = _git(project_dir, "worktree", "list", "--porcelain")
    if out is None:
        return 1  # unanswered — assume single tree (affects only the filename)
    return sum(1 for ln in out.splitlines() if ln.startswith("worktree ")) or 1


def log_basename(today: str, branch: str, topic: str, multi: bool) -> str:
    """Assemble the log filename.

    The topic says what the session was about and is what you actually want to
    read. The branch is only a disambiguator, and it is dead weight in a repo with
    a single worktree — where no second tree exists to collide with. So it is
    included only when the repo actually has more than one worktree.

    The invariant: whenever a collision is possible (multi), the branch is present,
    and git refuses to check one branch out in two worktrees. The topic cannot
    carry the guarantee on its own — a worktree inherits the main checkout's
    `quality_reports/plans/`, so two trees doing different work routinely compute
    the same topic, and two trees with no fresh plan compute no topic at all.

    `_slugify` strips `_`, which stays reserved as the field separator so a topic
    can never impersonate a `branch_topic` pair.
    """
    if not multi:
        return f"{today}_auto_{topic or branch}.md"
    return f"{today}_auto_{branch}_{topic}.md" if topic else f"{today}_auto_{branch}.md"


def _plan_ts(p: Path) -> float:
    """Age of a plan, from its `YYYY-MM-DD_` filename prefix.

    Not mtime: a sync, checkout, or copy rewrites mtime on every plan at once,
    which both destroys the ordering (everything ties on today) and makes a plan
    from months ago look fresh. The filename date is the convention this repo
    enforces and survives all of that.

    A plan with no date prefix does not follow the convention and cannot be dated
    at all — mtime would say "today" for a stray that has never been touched as
    work. Such files rank oldest, so a conforming plan always wins and a directory
    of only strays yields no topic (the caller then falls back to the branch).
    """
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})", p.name)
    if not m:
        return 0.0
    try:
        return datetime(int(m.group(1)), int(m.group(2)), int(m.group(3))).timestamp()
    except ValueError:
        return 0.0  # e.g. 2026-13-45


def _active_plan(project_dir: str) -> tuple[Path, str] | None:
    """Most recent non-completed plan, as (path, status). Shared by the filename
    topic and the in-entry `Active plan:` line so the two can never disagree."""
    plans = Path(project_dir) / "quality_reports" / "plans"
    if not plans.is_dir():
        return None
    try:
        files = sorted(plans.glob("*.md"), key=_plan_ts, reverse=True)
    except Exception:
        return None
    for p in files:
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        # Parse the Status FIELD, not a whole-file substring — a DRAFT plan that
        # merely mentions "APPROVED"/"COMPLETED" must not be mis-labelled.
        m = re.search(r"^\s*\**\s*status\s*\**\s*:\s*\**\s*"
                      r"(draft|approved|completed|implemented|in[ -]?progress)",
                      text, re.IGNORECASE | re.MULTILINE)
        v = m.group(1).lower() if m else "in-progress"
        if v.startswith(("completed", "implemented")):
            continue
        status = "APPROVED" if v.startswith("approved") else ("DRAFT" if v.startswith("draft") else "in-progress")
        return p, status
    return None


def _active_plan_file(project_dir: str) -> Path | None:
    hit = _active_plan(project_dir)
    return hit[0] if hit else None


def active_plan(project_dir: str) -> str | None:
    """The `Active plan:` line. A stale plan is REPORTED but LABELLED — the
    filename-topic side (topic_slug) drops it entirely, and an unlabelled
    90-day-old plan presented as current reads as fact."""
    hit = _active_plan(project_dir)
    if not hit:
        return None
    age_days = (datetime.now().timestamp() - _plan_ts(hit[0])) / 86400
    if age_days > TOPIC_STALE_DAYS:
        return f"{hit[0].name} ({hit[1]}, {int(age_days)} days old — likely stale)"
    return f"{hit[0].name} ({hit[1]})"


def uncompiled(project_dir: str) -> list[str]:
    """Slides/*.tex newer than its .pdf, Quarto/*.qmd newer than its .html."""
    flagged: list[str] = []
    root = Path(project_dir)
    for src, out_ext in ((root / "Slides", ".pdf"), (root / "Quarto", ".html")):
        if not src.is_dir():
            continue
        for f in src.glob("*.tex" if out_ext == ".pdf" else "*.qmd"):
            out = f.with_suffix(out_ext)
            try:
                if not out.exists() or f.stat().st_mtime > out.stat().st_mtime:
                    flagged.append(f"{f.relative_to(root)} → no fresh {out_ext}")
            except Exception:
                continue
    return flagged


def main() -> int:
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        hook_input = {}

    # Avoid Stop-hook loops.
    if hook_input.get("stop_hook_active", False):
        return 0

    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "") or hook_input.get("cwd", "")
    if not project_dir or not Path(project_dir).is_dir():
        return 0

    status = _git(project_dir, "status", "--porcelain")
    if status is None:
        return 0  # git did not ANSWER — unknown tree; do not claim "clean"
    if not status.strip():
        return 0  # answered: genuinely clean — nothing to log

    branch = branch_slug(project_dir)
    today = datetime.now().strftime("%Y-%m-%d")
    basename = log_basename(today, branch, topic_slug(project_dir),
                            worktree_count(project_dir) > 1)

    # Throttle per log file, not per project: the filename is now branch- and
    # topic-scoped, so a single shared hash would let a branch switch (or a new
    # plan) with an unchanged status suppress that file's first entry, leaving it
    # empty.
    state_path = get_state_dir() / "session-log-state.json"
    status_hash = hashlib.md5(status.encode()).hexdigest()
    try:
        state = json.loads(state_path.read_text())
        hashes = state.get("hashes") if isinstance(state, dict) else None
        hashes = hashes if isinstance(hashes, dict) else {}
    except Exception:
        hashes = {}
    if status_hash == hashes.get(basename):
        return 0  # already logged this exact change-set to this file

    logs = Path(project_dir) / "quality_reports" / "session_logs"
    logs.mkdir(parents=True, exist_ok=True)
    log_file = logs / basename
    new_file = not log_file.exists()

    changed = [ln for ln in status.splitlines() if ln.strip()][:30]
    plan = active_plan(project_dir)
    flagged = uncompiled(project_dir)

    # Two sessions can share one branch and one working tree, so stamp each entry
    # with the session id — the filename alone cannot tell them apart.
    session = str(hook_input.get("session_id", ""))[:8]

    lines = []
    if new_file:
        lines.append(f"# Session Log — {today} (auto, branch `{branch}`)\n")
        lines.append("_Auto-written by the Stop hook on each meaningful change-set. "
                     "Narrative notes welcome alongside._\n")
    header = f"\n## {datetime.now().strftime('%H:%M')} — {len(changed)} file(s) touched"
    lines.append(f"{header} _(session {session})_" if session else header)
    if plan:
        lines.append(f"\n**Active plan:** {plan}")
    lines.append("\n**Changed:**")
    lines.extend(f"- `{ln.strip()}`" for ln in changed)
    if flagged:
        lines.append("\n**Uncompiled artifacts:**")
        lines.extend(f"- {x}" for x in flagged)
    lines.append("")

    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
    except Exception:
        return 0

    try:
        hashes[basename] = status_hash
        state_path.write_text(json.dumps({"hashes": hashes}))
    except Exception:
        pass

    sys.stderr.write(f"[session-log] appended {len(changed)} change(s) to {log_file.name}\n")

    # Opt-in compile gate: turn the uncompiled note into a Stop-block.
    if flagged and os.environ.get("CLAUDE_COMPILE_GATE", "") == "block":
        reason = ("Uncompiled artifacts before stop: " + "; ".join(flagged) +
                  ". Run /compile-latex or /deploy, or set CLAUDE_COMPILE_GATE= to disable this gate.")
        json.dump({"decision": "block", "reason": reason}, sys.stdout)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)  # fail open
