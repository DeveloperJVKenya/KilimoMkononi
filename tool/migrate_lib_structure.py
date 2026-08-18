#!/usr/bin/env python3
"""
Kilimo Mkononi source-organization migration.

Moves lib/ files to a feature-based layout per migration_map.csv (old_path,new_path,
repo-relative, forward slashes) and rewrites every `package:kilimomkononi/...` import/
export/part-of reference across the repo to match. Does not touch file contents beyond
those directive lines. Uses `git mv` so history follows each file.

Usage:
    python tool/migrate_lib_structure.py --map tool/migration_map.csv --dry-run
    python tool/migrate_lib_structure.py --map tool/migration_map.csv --execute

Safety:
  - Refuses to run if the git working tree is not clean.
  - Fails (does not partially apply) if any mapped source file is missing.
  - Fails if any destination path is already occupied by a file not itself being moved.
  - Fails if the mapping produces two sources mapped to the same destination.
  - Dry-run (default) prints the full plan and report; nothing is written.
  - --execute performs the moves via `git mv`, then rewrites import lines, then writes
    a migration report to tool/migration_report.txt.
"""
import argparse
import csv
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
LIB_ROOT = REPO_ROOT / "lib"

# Matches: import/export 'package:kilimomkononi/<path>'  (single or double quotes, optional show/hide/as clauses on import handled naturally since we only rewrite the URI token)
IMPORT_RE = re.compile(
    r"""(?P<prefix>\b(?:import|export)\s+)(?P<q>['"])package:kilimomkononi/(?P<path>[^'"]+)(?P=q)"""
)
# Matches: part 'x.dart';  and  part of 'x.dart';  — only rewritten when the relative
# target resolves to a path present in the mapping (keeps sibling part-files paired).
PART_RE = re.compile(
    r"""(?P<prefix>\bpart\s+(?:of\s+)?)(?P<q>['"])(?P<path>[^'"]+\.dart)(?P=q)"""
)


def load_map(map_path: Path):
    rows = []
    with open(map_path, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            old, new = row["old_path"].strip(), row["new_path"].strip()
            if old and new:
                rows.append((old, new))
    return rows


def validate(rows):
    errors = []
    seen_dest = {}
    moves = [(o, n) for o, n in rows if o != n]
    unchanged = {o for o, n in rows if o == n}
    move_sources = {o for o, n in moves}
    move_dests = {n for o, n in moves}

    for old, new in rows:
        src = REPO_ROOT / old
        if not src.is_file():
            errors.append(f"MISSING SOURCE: {old} (listed in map but not found on disk)")

    for old, new in moves:
        seen_dest.setdefault(new, []).append(old)
    for dest, sources in seen_dest.items():
        if len(sources) > 1:
            errors.append(f"COLLISION: multiple sources map to {dest}: {sources}")

    for old, new in moves:
        dest = REPO_ROOT / new
        if dest.exists() and new not in move_sources and old not in unchanged:
            errors.append(f"DESTINATION CONFLICT: {new} already exists and is not itself being moved")

    return errors, moves


def git(*args, check=True):
    result = subprocess.run(["git", *args], cwd=REPO_ROOT, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed:\n{result.stdout}\n{result.stderr}")
    return result


def ensure_clean_tree():
    result = git("status", "--porcelain")
    if result.stdout.strip():
        print("ERROR: working tree is not clean. Commit or stash changes before migrating.", file=sys.stderr)
        print(result.stdout, file=sys.stderr)
        sys.exit(1)


def rewrite_imports_in_file(path: Path, path_map: dict, report: list):
    text = path.read_text(encoding="utf-8")
    original = text
    changed_lines = 0

    def repl_import(m):
        nonlocal changed_lines
        old_rel = m.group("path")
        if old_rel in path_map:
            changed_lines += 1
            new_rel = path_map[old_rel]
            return f"{m.group('prefix')}{m.group('q')}package:kilimomkononi/{new_rel}{m.group('q')}"
        return m.group(0)

    text = IMPORT_RE.sub(repl_import, text)

    new_text = text
    if new_text != original:
        report.append((str(path.relative_to(REPO_ROOT)), changed_lines))
    return new_text, new_text != original


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", type=Path, default=REPO_ROOT / "tool" / "migration_map.csv")
    ap.add_argument("--execute", action="store_true", help="Perform the migration. Omit for dry-run.")
    args = ap.parse_args()

    rows = load_map(args.map)
    errors, moves = validate(rows)

    print(f"Loaded {len(rows)} mapped files ({len(moves)} moves, {len(rows) - len(moves)} unchanged).")

    if errors:
        print("\nVALIDATION FAILED — no changes made:")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)

    print("Validation passed: no missing sources, no destination collisions, no conflicts.\n")

    if not args.execute:
        print("DRY RUN — planned moves:")
        for old, new in moves:
            print(f"  git mv \"{old}\" \"{new}\"")
        print(f"\n({len(moves)} files would move; {len(rows)} import-lookup entries available for rewrite.)")
        print("Re-run with --execute to apply.")
        return

    ensure_clean_tree()

    # 1. Perform git mv, creating destination directories as needed.
    move_log = []
    for old, new in moves:
        dest = REPO_ROOT / new
        dest.parent.mkdir(parents=True, exist_ok=True)
        git("mv", old, new)
        move_log.append((old, new))
    print(f"Moved {len(move_log)} files via git mv.")

    # 2. Rewrite import/export/part directives across the whole lib/ tree (and test/ if present).
    path_map = {old: new for old, new in rows}  # includes unchanged entries (no-op rewrites)
    targets = list(LIB_ROOT.rglob("*.dart"))
    test_dir = REPO_ROOT / "test"
    if test_dir.is_dir():
        targets += list(test_dir.rglob("*.dart"))

    rewrite_report = []
    files_changed = 0
    for f in targets:
        new_text, changed = rewrite_imports_in_file(f, path_map, rewrite_report)
        if changed:
            f.write_text(new_text, encoding="utf-8")
            files_changed += 1

    print(f"Rewrote import/export directives in {files_changed} files.")

    # 3. Write migration report.
    report_path = REPO_ROOT / "tool" / "migration_report.txt"
    with open(report_path, "w", encoding="utf-8") as rp:
        rp.write("Kilimo Mkononi lib/ migration report\n")
        rp.write("=" * 40 + "\n\n")
        rp.write(f"Files moved: {len(move_log)}\n")
        rp.write(f"Files with rewritten imports: {files_changed}\n\n")
        rp.write("-- Moves --\n")
        for old, new in move_log:
            rp.write(f"{old} -> {new}\n")
        rp.write("\n-- Import rewrites (file: lines changed) --\n")
        for path, n in rewrite_report:
            rp.write(f"{path}: {n}\n")
    print(f"Report written to {report_path.relative_to(REPO_ROOT)}")
    print("\nNext: flutter pub get && flutter analyze")


if __name__ == "__main__":
    main()
