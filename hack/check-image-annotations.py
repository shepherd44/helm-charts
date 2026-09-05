#!/usr/bin/env python3
"""Check that a chart's image annotation matches what it actually renders.

`annotations.images` is not documentation. The bundled `common` library calls
`common.errors.insecureImages` from NOTES.txt and compares every rendered image
against that list; a stale list either fails an install or, once the list names
our own registry, reports the wrong images to whoever installs the chart.

Both spellings are checked: bitnami's `images` and Artifact Hub's
`artifacthub.io/images`. Charts with neither are skipped.

    python3 hack/check-image-annotations.py charts/mongodb-sharded -- --set metrics.enabled=true
"""
import argparse
import pathlib
import re
import subprocess
import sys

import yaml


def annotated_images(chart):
    meta = yaml.safe_load((chart / "Chart.yaml").read_text())
    annotations = meta.get("annotations") or {}
    raw = annotations.get("images") or annotations.get("artifacthub.io/images")
    if not raw:
        return None
    return {e["image"] for e in yaml.safe_load(raw)}


def rendered_images(chart, extra):
    out = subprocess.run(
        ["helm", "template", "check", str(chart), *extra],
        capture_output=True, text=True, check=True,
    ).stdout
    # `image: "repo:tag"` and `image: repo:tag`, container and initContainer alike.
    return {m.group(1) for m in re.finditer(r'^\s*image:\s*"?([^"\s]+)"?\s*$', out, re.M)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("chart", type=pathlib.Path)
    ap.add_argument("helm_args", nargs=argparse.REMAINDER,
                    help="extra helm template flags; everything after the chart path")
    args = ap.parse_args()

    annotated = annotated_images(args.chart)
    if annotated is None:
        print(f"skip {args.chart}: no image annotation")
        return 0

    rendered = rendered_images(args.chart, args.helm_args)
    problems = []
    for image in sorted(rendered - annotated):
        problems.append(f"rendered but not annotated: {image}")
    for image in sorted(annotated - rendered):
        problems.append(f"annotated but never rendered: {image}")

    for p in problems:
        print(f"FAIL {args.chart}: {p}", file=sys.stderr)
    if problems:
        print(
            "\nannotations.images in Chart.yaml has to list exactly what the chart "
            "renders with its optional pieces switched on.",
            file=sys.stderr,
        )
        return 1
    print(f"OK {args.chart}: {len(rendered)} rendered images all annotated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
