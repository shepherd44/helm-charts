#!/usr/bin/env python3
"""Check that the published chart repo in docs/ is internally consistent.

A published version is immutable: docs/*.tgz are artifacts people have already
pulled. This asserts three things, in the order they are worth knowing:

  1. every version listed in index.yaml has its .tgz present
  2. every .tgz hashes to the digest the index claims
  3. no version that already existed on the baseline branch has a changed digest
  4. nor a changed `created` timestamp

Point 4 is not cosmetic bookkeeping: `helm repo index --merge` regenerates the
entry for every .tgz still sitting in docs/, so under Helm 4 it rewrites all of
their `created` timestamps and a one-chart release shows up as a diff touching
every chart. Run with --restore-created after indexing to put them back.

Run it locally the same way CI does:

    git show origin/main:docs/index.yaml > /tmp/base-index.yaml
    python3 hack/verify-index.py docs --baseline /tmp/base-index.yaml
"""
import argparse
import hashlib
import pathlib
import sys

import yaml


def entries(index):
    """(chart, version, entry). helm writes the digest as bare hex; digest_of()
    tolerates a sha256: prefix so a hand-edited index does not read as a mismatch."""
    for name, versions in (index.get("entries") or {}).items():
        for entry in versions:
            yield name, entry["version"], entry


def digest_of(entry):
    return str(entry.get("digest", "")).removeprefix("sha256:")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("docs", type=pathlib.Path)
    ap.add_argument("--baseline", type=pathlib.Path, help="index.yaml from the target branch")
    ap.add_argument(
        "--restore-created",
        action="store_true",
        help="rewrite index.yaml, putting back the baseline's created timestamps",
    )
    args = ap.parse_args()

    index_path = args.docs / "index.yaml"
    index = yaml.safe_load(index_path.read_text())
    baseline = None
    if args.baseline and args.baseline.exists():
        baseline = yaml.safe_load(args.baseline.read_text()) or {}

    if args.restore_created:
        if baseline is None:
            print("FAIL --restore-created needs a --baseline", file=sys.stderr)
            return 1
        was = {(n, v): e.get("created") for n, v, e in entries(baseline)}
        # Edited as text, not round-tripped through the YAML dumper: rewriting the
        # file would rewrite quoting and block scalars too, turning a one-line fix
        # into a diff across the whole index. Each entry's digest is unique, so it
        # locates the entry; `created` is the nearest key above it.
        lines = index_path.read_text().splitlines(keepends=True)
        restored = 0
        for name, version, entry in entries(index):
            created = was.get((name, version))
            if created is None or entry.get("created") == created:
                continue
            marker = f"digest: {entry.get('digest', '')}"
            at = next(i for i, line in enumerate(lines) if marker in line)
            back = next(i for i in range(at, -1, -1) if lines[i].lstrip().startswith("created:"))
            indent = lines[back][: len(lines[back]) - len(lines[back].lstrip())]
            lines[back] = f'{indent}created: "{created}"\n'
            restored += 1
        index_path.write_text("".join(lines))
        index = yaml.safe_load(index_path.read_text())
        print(f"restored {restored} created timestamps from {args.baseline}")

    problems = []

    for name, version, entry in entries(index):
        digest = digest_of(entry)
        tgz = args.docs / f"{name}-{version}.tgz"
        if not tgz.exists():
            problems.append(f"{name} {version}: index lists it, {tgz} is missing")
            continue
        actual = hashlib.sha256(tgz.read_bytes()).hexdigest()
        if actual != digest:
            problems.append(f"{name} {version}: digest is {actual}, index says {digest}")

    if baseline is not None:
        published = {(n, v): e for n, v, e in entries(baseline)}
        for name, version, entry in entries(index):
            before = published.get((name, version))
            if before is None:
                continue
            if digest_of(before) != digest_of(entry):
                problems.append(
                    f"{name} {version} was already published with digest "
                    f"{digest_of(before)} and now has {digest_of(entry)} — bump the "
                    f"version instead of repackaging it"
                )
            if before.get("created") != entry.get("created"):
                problems.append(
                    f"{name} {version}: created changed from {before.get('created')} to "
                    f"{entry.get('created')} — rerun with --restore-created; `helm repo "
                    f"index --merge` rewrites these for every .tgz in the directory"
                )

    for p in problems:
        print(f"FAIL {p}", file=sys.stderr)
    if problems:
        return 1
    print(f"OK {sum(1 for _ in entries(index))} published chart versions verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
