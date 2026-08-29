#!/usr/bin/env bash
#
# sync-from-template.sh — push this template's infrastructure into a downstream project.
#
# WHY THIS EXISTS
# ---------------
# Downstream research projects vendor this repo's .claude/ + scripts/ by file copy and
# adapt a few files. Hand-propagating template updates does not scale, and the naive
# rsync approach (a downstream once shipped one) clobbers adaptations. This tool makes
# the update a two-command ritual with hard safety properties:
#
#   * The payload is the blobs of ONE template commit (git show $SHA:path), never the
#     working tree — a dirty template cannot leak uncommitted state downstream
#     (release-engineering.md §5).
#   * Classification is driven by a RECORDED MANIFEST (the downstream's tracked
#     .claude/workflow-pin.json: path -> blob-hash-as-applied), not by git-history
#     archaeology — deterministic on every machine, immune to this repo's rebase
#     force-pushes (main is a patch queue; old SHAs are rewritten and pruned).
#   * A file the downstream edited since the last sync is NEVER overwritten; it is
#     reported and the run exits 1. The tool never edits the exclude manifest to make
#     its own run green (release-engineering.md §4: the re-sync tool decides nothing).
#   * Adapted files listed as `merge` in .claude/sync-exclude are 3-way merged
#     (git merge-file) against a tracked base copy in .claude/sync-base/ — template
#     improvements flow in; only genuinely overlapping edits leave conflict markers.
#
# Usage:
#   scripts/sync-from-template.sh <downstream-root>            # report (no writes)
#   scripts/sync-from-template.sh <downstream-root> --apply    # apply + update pin
#   scripts/sync-from-template.sh --selftest                   # seeded fixture test
#
# Downstream control files (all tracked in the downstream repo):
#   .claude/sync-exclude       lines: "merge <repo-relative-path>" | "keep <path>" | # comment
#   .claude/sync-base/<path>   base copies for merge-mode files (advanced by --apply)
#   .claude/workflow-pin.json  {template_sha, synced_at, files: {path: blob_sha}}
#
# Exit codes: 0 = clean/applied, 1 = drift needing a human (locally-edited files,
# merge conflicts, manifest errors), 2 = could-not-run.
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)" || exit 2

exec python3 - "$REPO_ROOT" "$@" <<'PY'
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

MARKER = ".claude/references/finding-schema.json"  # template identity sentinel


def die(msg, code=2):
    print(f"sync-from-template: {msg}", file=sys.stderr)
    sys.exit(code)


def git(root, *args, binary=False):
    r = subprocess.run(["git", "-C", str(root), *args],
                       capture_output=True, text=not binary)
    if r.returncode != 0:
        err = r.stderr if isinstance(r.stderr, str) else r.stderr.decode("utf-8", "replace")
        die(f"git {' '.join(args[:2])}... failed: {err.strip()[:200]}")
    return r.stdout


def blob_sha(content: bytes) -> str:
    h = hashlib.sha1()
    h.update(b"blob %d\0" % len(content))
    h.update(content)
    return h.hexdigest()


def managed(path: str) -> bool:
    """Is this template path in sync scope?"""
    if "__pycache__" in path or path.endswith((".pyc", ".DS_Store")):
        return False
    if path.startswith(".claude/"):
        rel = path[len(".claude/"):]
        if rel.startswith(("state/", "worktrees/", "sync-base/")):
            return False
        if rel in ("settings.local.json", "sync-exclude", "workflow-pin.json"):
            return False
        return True
    if path.startswith("scripts/") and "/" not in path[len("scripts/"):]:
        return True  # top-level scripts only; scripts/R/ etc. stay out by design
    return False


def load_manifest(downstream: Path):
    """Parse .claude/sync-exclude -> {path: 'merge'|'keep'}."""
    f = downstream / ".claude" / "sync-exclude"
    entries = {}
    if not f.is_file():
        return entries
    for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^(merge|keep)\s+(\S+)$", line)
        if not m:
            die(f".claude/sync-exclude:{i}: cannot parse {line!r} "
                f"(expected 'merge <path>' or 'keep <path>')")
        entries[m.group(2)] = m.group(1)
    return entries


def load_pin(downstream: Path):
    f = downstream / ".claude" / "workflow-pin.json"
    if not f.is_file():
        return None
    try:
        pin = json.loads(f.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        die(f"{f} is not valid JSON ({e}) — fix or remove it")
    return pin if isinstance(pin, dict) else None


def write_pin_atomic(downstream: Path, pin: dict):
    f = downstream / ".claude" / "workflow-pin.json"
    fd, tmp = tempfile.mkstemp(dir=str(f.parent), prefix=".pin-")
    with os.fdopen(fd, "w", encoding="utf-8") as h:
        json.dump(pin, h, indent=2, sort_keys=True)
        h.write("\n")
    os.replace(tmp, f)


def merge3(base: bytes, theirs: bytes, new: bytes):
    """git merge-file. Returns (merged_bytes, n_conflicts)."""
    with tempfile.TemporaryDirectory() as d:
        pb, pt, pn = (os.path.join(d, n) for n in ("base", "theirs", "new"))
        for p, c in ((pb, base), (pt, theirs), (pn, new)):
            with open(p, "wb") as h:
                h.write(c)
        r = subprocess.run(
            ["git", "merge-file", "-p",
             "-L", "PROJECT (yours)", "-L", "BASE (last sync)", "-L", "TEMPLATE (new)",
             pt, pb, pn],
            capture_output=True)
        if r.returncode < 0:
            die("git merge-file crashed")
        return r.stdout, r.returncode  # rc = number of conflicts


def run_sync(template: Path, downstream: Path, apply: bool) -> int:
    # ---- identity + safety gates -------------------------------------------
    if not (template / MARKER).is_file() or not (template / "CHANGELOG.md").is_file():
        die(f"{template} does not look like the template repo (sentinel missing)")
    if not (downstream / ".claude").is_dir():
        die(f"{downstream} has no .claude/ — not an initialized downstream")
    if template.resolve() == downstream.resolve():
        die("template root == downstream root — you are running a downstream copy of "
            "this script on itself; run the TEMPLATE's copy (e.g. via the "
            "claude-code-my-workflow symlink) instead", 2)
    gitdir = git(template, "rev-parse", "--git-dir").strip()
    gd = Path(gitdir) if os.path.isabs(gitdir) else template / gitdir
    if (gd / "rebase-merge").exists() or (gd / "rebase-apply").exists():
        die("template has a rebase in progress — finish it first")
    if subprocess.run(["git", "-C", str(template), "symbolic-ref", "-q", "HEAD"],
                      capture_output=True).returncode != 0:
        die("template HEAD is detached — check out a branch first")

    sha = git(template, "rev-parse", "HEAD").strip()
    sha_date = int(git(template, "show", "-s", "--format=%ct", sha).strip())

    # ---- template file list at the ONE resolved commit ---------------------
    tree = {}  # path -> (mode, blob_sha)
    for line in git(template, "ls-tree", "-r", sha,
                    "--", ".claude", "scripts").splitlines():
        meta, path = line.split("\t", 1)
        mode, typ, bsha = meta.split()
        if typ == "blob" and managed(path):
            tree[path] = (mode, bsha)

    dirty = git(template, "status", "--porcelain", "--", ".claude", "scripts").strip()

    manifest = load_manifest(downstream)
    pin = load_pin(downstream)
    recorded = (pin or {}).get("files", {})
    bootstrap = pin is None or not recorded

    # Stale-clone guard: a behind-origin template clone syncing "backwards" looks
    # plausible in every other respect. synced_at is ISO UTC.
    if pin and pin.get("synced_at"):
        try:
            pinned_t = time.mktime(time.strptime(pin["synced_at"][:19], "%Y-%m-%dT%H:%M:%S"))
        except ValueError:
            pinned_t = 0
        if pinned_t and sha_date < pinned_t - 60:
            print("!! WARNING: template HEAD is OLDER than the last sync — this clone "
                  "is probably behind origin. Pull it first.")
            if apply and not os.environ.get("SYNC_ALLOW_OLDER"):
                die("refusing --apply from an older template (set SYNC_ALLOW_OLDER=1 "
                    "to override)")

    # ---- manifest sanity: every entry must exist in the template -----------
    problems = []
    for mpath in manifest:
        if mpath not in tree:
            problems.append(
                f"sync-exclude entry '{mpath}' does not exist in the template at "
                f"{sha[:8]} — upstream renamed or deleted it; re-point or retire the "
                f"adaptation explicitly")

    # ---- classify -----------------------------------------------------------
    refresh, new, in_sync = [], [], []
    merges = {}        # path -> (merged_bytes, n_conflicts)
    keeps_changed = []
    locally_edited = []
    base_missing = []

    for path in sorted(tree):
        mode, t_sha = tree[path]
        d_file = downstream / path
        d_bytes = d_file.read_bytes() if d_file.is_file() else None
        d_sha = blob_sha(d_bytes) if d_bytes is not None else None

        if path in manifest:
            t_bytes = git(template, "cat-file", "blob", t_sha, binary=True)
            if manifest[path] == "keep":
                if d_sha != t_sha:
                    keeps_changed.append(path)
                continue
            # merge mode
            if d_bytes is None:
                new.append(path)  # nothing local yet: plain copy, base seeded on apply
                continue
            if d_sha == t_sha:
                in_sync.append(path)
                continue
            base_f = downstream / ".claude" / "sync-base" / path
            if not base_f.is_file():
                base_missing.append(path)
                continue
            merges[path] = merge3(base_f.read_bytes(), d_bytes, t_bytes)
            continue

        if d_bytes is None:
            new.append(path)
        elif d_sha == t_sha:
            in_sync.append(path)
        elif path in recorded and d_sha == recorded[path]:
            refresh.append(path)  # untouched since we wrote it; template moved
        elif bootstrap and subprocess.run(
                ["git", "-C", str(template), "cat-file", "-e", d_sha],
                capture_output=True).returncode == 0:
            refresh.append(path)  # bootstrap archaeology: content is a known template blob
        else:
            locally_edited.append(path)

    # downstream-only files under managed dirs (never deleted; orphans annotated)
    downstream_only = []
    for base_dir in (".claude", "scripts"):
        root = downstream / base_dir
        if not root.is_dir():
            continue
        for f in sorted(root.rglob("*")):
            if not f.is_file():
                continue
            rel = f.relative_to(downstream).as_posix()
            if not managed(rel) or rel in tree:
                continue
            tag = "  [was template-managed at last sync — deleted/renamed upstream]" \
                if rel in recorded else ""
            downstream_only.append(rel + tag)

    # ---- report -------------------------------------------------------------
    print(f"sync-from-template: template {sha[:12]} "
          f"({time.strftime('%Y-%m-%d', time.gmtime(sha_date))}) -> {downstream}")
    if bootstrap:
        print("   BOOTSTRAP MODE: no pin manifest yet — classification falls back to "
              "git-history archaeology and needs a full-history template clone.")
    if dirty:
        print(f"   note: template working tree is dirty in synced paths "
              f"({len(dirty.splitlines())} entries) — payload is HEAD, not the tree.")
    print(f"   in sync: {len(in_sync)}   refresh: {len(refresh)}   new: {len(new)}")

    rc = 0
    for p in refresh:
        print(f"   refresh  {p}")
    for p in new:
        print(f"   new      {p}")
    for p, (_, nconf) in sorted(merges.items()):
        state = "CONFLICTS" if nconf else "clean"
        print(f"   merge    {p}  [{state}]")
        if nconf:
            rc = 1
    for p in keeps_changed:
        print(f"   keep     {p}  (template side changed — not touched)")
    for p in base_missing:
        print(f"   merge    {p}  [ERROR: no base at .claude/sync-base/{p} — seed it]")
        rc = 1
    for p in locally_edited:
        print(f"   EDITED   {p}  — locally modified since last sync; NOT touched. "
              f"Add a sync-exclude entry or revert by hand.")
        rc = 1
    for msg in problems:
        print(f"   ERROR    {msg}")
        rc = 1
    for p in downstream_only:
        print(f"   local    {p}")

    if not apply:
        pending = refresh or new or any(n == 0 for _, n in merges.values())
        if pending and rc == 0:
            print("   report only — run with --apply to write these changes.")
            rc = 1 if (refresh or new or merges) else rc
        return rc

    # ---- apply --------------------------------------------------------------
    touched = []
    for p in refresh + new:
        mode, t_sha = tree[p]
        content = git(template, "cat-file", "blob", t_sha, binary=True)
        dest = downstream / p
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(content)
        if mode == "100755":
            os.chmod(dest, 0o755)
        touched.append(p)
        if p in manifest and manifest[p] == "merge":  # first arrival of a merge file
            bf = downstream / ".claude" / "sync-base" / p
            bf.parent.mkdir(parents=True, exist_ok=True)
            bf.write_bytes(content)
            touched.append((Path(".claude/sync-base") / p).as_posix())

    for p, (merged, nconf) in merges.items():
        (downstream / p).write_bytes(merged)
        # Advance the base to the NEW template version even on conflict: after the
        # user resolves the markers, future syncs re-merge only against template
        # changes newer than this one (otherwise every sync re-fights this conflict).
        _, t_sha = tree[p]
        bf = downstream / ".claude" / "sync-base" / p
        bf.parent.mkdir(parents=True, exist_ok=True)
        bf.write_bytes(git(template, "cat-file", "blob", t_sha, binary=True))
        touched.append(p)
        touched.append((Path(".claude/sync-base") / p).as_posix())

    # Pin records the hash AS APPLIED for every managed template path present
    # downstream, so the next run's "unchanged-since-sync" test is exact.
    files = {}
    for p in tree:
        f = downstream / p
        if f.is_file():
            files[p] = blob_sha(f.read_bytes())
    write_pin_atomic(downstream, {
        "template_sha": sha,
        "synced_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "files": files,
    })
    touched.append(".claude/workflow-pin.json")

    print(f"\napplied: {len(refresh)} refreshed, {len(new)} new, "
          f"{sum(1 for _, n in merges.values() if n == 0)} merged clean, "
          f"{sum(1 for _, n in merges.values() if n)} with CONFLICT MARKERS to resolve")

    # Post-apply verification (report-only): the freshly synced checkers catch
    # contract drift that reached project-only files (the Task->Agent class).
    for checker in ("scripts/check-skill-integrity.py", "scripts/check-staleness.py"):
        cf = downstream / checker
        if cf.is_file():
            r = subprocess.run(["python3", checker], cwd=str(downstream),
                               capture_output=True, text=True)
            tail = (r.stdout.strip().splitlines() or [""])[-1]
            print(f"   post-check {checker.split('/')[-1]}: rc={r.returncode}  {tail[:120]}")

    uniq = sorted(set(touched))
    print("\nstage the sync as ONE dedicated commit:")
    print(f"  git add {' '.join(uniq[:8])}{' ...' if len(uniq) > 8 else ''}")
    full = downstream / ".git" / "SYNC_TOUCHED"  # full list, for xargs
    try:
        full.write_text("\n".join(uniq) + "\n")
        print(f"  (full list of {len(uniq)} paths: .git/SYNC_TOUCHED — "
              f"`xargs git add < .git/SYNC_TOUCHED`)")
    except OSError:
        pass
    print(f"  git commit -m 'workflow-sync: template {sha[:12]}'")
    return rc


# --------------------------------------------------------------------------- #
# selftest: seeded fixtures for every classification + the safety invariants  #
# --------------------------------------------------------------------------- #
def selftest(script_repo_root: Path) -> int:
    import shutil
    failures = []

    def check(name, cond):
        print(f"  {'PASS' if cond else 'FAIL'}  {name}")
        if not cond:
            failures.append(name)

    with tempfile.TemporaryDirectory() as d:
        tpl = Path(d) / "template"
        dwn = Path(d) / "downstream"
        (tpl / ".claude" / "references").mkdir(parents=True)
        (tpl / ".claude" / "rules").mkdir(parents=True)
        (tpl / "scripts").mkdir()
        (dwn / ".claude" / "rules").mkdir(parents=True)
        (dwn / ".claude" / "sync-base" / ".claude" / "rules").mkdir(parents=True)

        # template content
        (tpl / MARKER).write_text("{}\n")
        (tpl / "CHANGELOG.md").write_text("## v9.9.9\n")
        (tpl / ".claude" / "rules" / "same.md").write_text("identical\n")
        (tpl / ".claude" / "rules" / "moved.md").write_text("template v2\n")
        (tpl / ".claude" / "rules" / "edited.md").write_text("template v2\n")
        (tpl / ".claude" / "rules" / "brandnew.md").write_text("brand new\n")
        (tpl / ".claude" / "rules" / "kept.md").write_text("template side\n")
        (tpl / ".claude" / "rules" / "merged.md").write_text(
            "line1 template-improved\nline2\nline3\nline4\nline5\nline6\nline7\n")
        (tpl / ".claude" / "rules" / "conflicted.md").write_text("both changed this line (template)\n")
        (tpl / "scripts" / "tool.py").write_text("print('v2')\n")
        for cmd in (["git", "init", "-q"], ["git", "add", "-A"],
                    ["git", "-c", "user.email=t@t", "-c", "user.name=t",
                     "commit", "-qm", "fixture"]):
            subprocess.run(cmd, cwd=tpl, capture_output=True)

        old = lambda s: s.encode()
        # downstream state
        (dwn / ".claude" / "rules" / "same.md").write_text("identical\n")
        (dwn / ".claude" / "rules" / "moved.md").write_text("template v1\n")     # recorded
        (dwn / ".claude" / "rules" / "edited.md").write_text("my local edit\n")  # != recorded
        (dwn / ".claude" / "rules" / "kept.md").write_text("my kept version\n")
        (dwn / ".claude" / "rules" / "merged.md").write_text(
            "line1\nline2\nline3\nline4\nline5\nline6\nline7 project-adapted\n")
        (dwn / ".claude" / "rules" / "conflicted.md").write_text("both changed this line (project)\n")
        (dwn / ".claude" / "rules" / "mine-only.md").write_text("project only\n")
        (dwn / "scripts").mkdir()
        (dwn / "scripts" / "tool.py").write_text("print('v1')\n")                # recorded
        (dwn / ".claude" / "sync-base" / ".claude" / "rules" / "merged.md").write_text(
            "line1\nline2\nline3\nline4\nline5\nline6\nline7\n")
        (dwn / ".claude" / "sync-base" / ".claude" / "rules" / "conflicted.md").write_text("both changed this line\n")
        (dwn / ".claude" / "sync-exclude").write_text(
            "merge .claude/rules/merged.md\n"
            "merge .claude/rules/conflicted.md\n"
            "keep .claude/rules/kept.md\n")
        write_pin_atomic(dwn, {
            "template_sha": "0" * 40,
            "synced_at": "2020-01-01T00:00:00Z",
            "files": {
                ".claude/rules/same.md": blob_sha(old("identical\n")),
                ".claude/rules/moved.md": blob_sha(old("template v1\n")),
                ".claude/rules/edited.md": blob_sha(old("template v1\n")),
                "scripts/tool.py": blob_sha(old("print('v1')\n")),
            },
        })

        # wrong-root refusal
        r = subprocess.run([sys.executable, "-c", "pass"])  # placeholder no-op
        script = script_repo_root / "scripts" / "sync-from-template.sh"
        env = dict(os.environ, SYNC_TEMPLATE_ROOT=str(tpl))
        r = subprocess.run(["bash", str(script), str(tpl)], env=env,
                           capture_output=True, text=True)
        check("wrong-root (template==downstream) refused rc=2",
              r.returncode == 2 and "on itself" in r.stderr + r.stdout)

        # report mode
        r = subprocess.run(["bash", str(script), str(dwn)], env=env,
                           capture_output=True, text=True)
        out = r.stdout
        check("report exits 1 (drift present)", r.returncode == 1)
        check("refresh classified", "refresh  .claude/rules/moved.md" in out)
        check("new classified", "new      .claude/rules/brandnew.md" in out)
        check("locally-edited refused", "EDITED   .claude/rules/edited.md" in out)
        check("keep reported not touched", "keep     .claude/rules/kept.md" in out)
        check("merge clean detected", "merge    .claude/rules/merged.md  [clean]" in out)
        check("merge conflict detected",
              "merge    .claude/rules/conflicted.md  [CONFLICTS]" in out)
        check("downstream-only listed", "local    .claude/rules/mine-only.md" in out)
        check("report wrote nothing",
              (dwn / ".claude" / "rules" / "moved.md").read_text() == "template v1\n")

        # apply
        r = subprocess.run(["bash", str(script), str(dwn), "--apply"], env=env,
                           capture_output=True, text=True)
        check("apply exits 1 (conflict remains)", r.returncode == 1)
        check("refresh applied",
              (dwn / ".claude" / "rules" / "moved.md").read_text() == "template v2\n")
        check("new applied",
              (dwn / ".claude" / "rules" / "brandnew.md").is_file())
        check("locally-edited NOT overwritten",
              (dwn / ".claude" / "rules" / "edited.md").read_text() == "my local edit\n")
        check("keep NOT overwritten",
              (dwn / ".claude" / "rules" / "kept.md").read_text() == "my kept version\n")
        merged = (dwn / ".claude" / "rules" / "merged.md").read_text()
        check("clean merge combined both sides",
              "template-improved" in merged and "project-adapted" in merged)
        conf = (dwn / ".claude" / "rules" / "conflicted.md").read_text()
        check("conflict markers written", "<<<<<<<" in conf and ">>>>>>>" in conf)
        base_after = (dwn / ".claude" / "sync-base" / ".claude" / "rules" / "conflicted.md").read_text()
        check("base advanced on conflict",
              base_after == "both changed this line (template)\n")
        pin2 = load_pin(dwn)
        check("pin updated with template sha",
              pin2 and pin2["template_sha"] != "0" * 40)

        # idempotence: resolve the conflict, re-run -> clean
        (dwn / ".claude" / "rules" / "conflicted.md").write_text("resolved by hand\n")
        (dwn / ".claude" / "rules" / "edited.md").write_text("template v2\n")  # user reverted
        r = subprocess.run(["bash", str(script), str(dwn), "--apply"], env=env,
                           capture_output=True, text=True)
        check("post-resolution re-apply is clean rc=0", r.returncode == 0)
        check("resolution survives re-apply",
              (dwn / ".claude" / "rules" / "conflicted.md").read_text() == "resolved by hand\n")

    print(f"selftest: {'ALL PASS' if not failures else f'{len(failures)} FAILURE(S)'}")
    return 0 if not failures else 1


def main():
    argv = sys.argv[1:]
    repo_root = Path(argv[0])
    args = argv[1:]
    if args and args[0] == "--selftest":
        sys.exit(selftest(repo_root))
    if not args:
        die("usage: sync-from-template.sh <downstream-root> [--apply] | --selftest")
    downstream = Path(args[0]).expanduser()
    if not downstream.is_dir():
        die(f"downstream root {downstream} does not exist")
    apply = "--apply" in args[1:]
    template = Path(os.environ.get("SYNC_TEMPLATE_ROOT", repo_root))
    sys.exit(run_sync(template, downstream, apply))


main()
PY
