#!/usr/bin/env python3
"""Check that the published chart repo in docs/ is internally consistent.

A published version is immutable: docs/*.tgz are artifacts people have already
pulled. This asserts three things, in the order they are worth knowing:

  1. every version listed in index.yaml has its .tgz present
  2. every .tgz hashes to the digest the index claims
  3. no version that already existed on the baseline branch has a changed digest

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
    """(chart, version, digest). helm writes the digest as bare hex; tolerate a
    sha256: prefix so a hand-edited index does not read as a mismatch."""
    for name, versions in (index.get("entries") or {}).items():
        for entry in versions:
            digest = str(entry.get("digest", ""))
            yield name, entry["version"], digest.removeprefix("sha256:")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("docs", type=pathlib.Path)
    ap.add_argument("--baseline", type=pathlib.Path, help="index.yaml from the target branch")
    args = ap.parse_args()

    index = yaml.safe_load((args.docs / "index.yaml").read_text())
    problems = []

    for name, version, digest in entries(index):
        tgz = args.docs / f"{name}-{version}.tgz"
        if not tgz.exists():
            problems.append(f"{name} {version}: index lists it, {tgz} is missing")
            continue
        actual = hashlib.sha256(tgz.read_bytes()).hexdigest()
        if actual != digest:
            problems.append(f"{name} {version}: digest is {actual}, index says {digest}")

    if args.baseline and args.baseline.exists():
        base = yaml.safe_load(args.baseline.read_text()) or {}
        published = {(n, v): d for n, v, d in entries(base)}
        for name, version, digest in entries(index):
            was = published.get((name, version))
            if was is not None and was != digest:
                problems.append(
                    f"{name} {version} was already published with digest {was} and now has "
                    f"{digest} — bump the version instead of repackaging it"
                )

    for p in problems:
        print(f"FAIL {p}", file=sys.stderr)
    if problems:
        return 1
    print(f"OK {sum(1 for _ in entries(index))} published chart versions verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
