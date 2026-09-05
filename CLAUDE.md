# CLAUDE.md

A Helm chart repository served as a static chart repo from GitHub Pages. `README.md` is
the human-facing document; this file is the part an agent gets wrong without being told.

## Layout

```
charts/<name>/     chart sources — the thing you edit
charts/common/     bitnami library chart, dependency only, never published on its own
docs/              the published chart repo: *.tgz + index.yaml + index.html
```

GitHub Pages serves the repo root of `main` (legacy Jekyll build, no workflow), so
`docs/` is live a minute or two after a push. `docs/` is a build output that is
committed on purpose — do not gitignore it, and do not hand-edit `index.yaml`.

## Work in a worktree

**Never edit the primary checkout.** Every change — code, chart, docs — starts with a
git worktree off `origin/main`:

```shell
BR=<type>/<short-name>            # feat, fix, chore, docs
git fetch -q origin
git worktree add -b "$BR" "/Users/james/workspace/helm-charts-wt/$BR" origin/main
cd "/Users/james/workspace/helm-charts-wt/$BR"
```

`<repo>-wt/<branch>/` is the layout the other repos on this machine already use, so the
path mirrors the branch name and several can exist at once.

Branch off `origin/main`, not the local branch: the primary checkout is often parked on
something unrelated, and `git worktree add` inherits whatever HEAD it is given.

After the branch is merged, remove the worktree — a stale one is a second checkout that
silently goes out of date:

```shell
git worktree remove /Users/james/workspace/helm-charts-wt/$BR
git branch -d $BR
```

Package and index inside the worktree, so `docs/` and the chart change land in the same
commit. Publishing still only happens when that commit reaches `main`.

## Rules

**A published version is immutable.** `docs/` holds real artifacts people may have
pulled. Never repackage an existing version with different content — bump the version.
Deleting a published `.tgz` is only acceptable for a release that was live briefly and
is superseded, and it needs saying out loud in the commit.

**Regenerate the index with `--merge`,** otherwise `created` timestamps for untouched
charts churn:

```shell
helm repo index docs --url https://shepherd44.github.io/helm-charts/docs --merge docs/index.yaml
```

**Run `helm dependency update` before packaging** any chart with dependencies.
`charts/mongodb-sharded` depends on `file://../common`, and the built
`charts/mongodb-sharded/charts/common-*.tgz` is gitignored but must exist at package
time or `common` silently drops out of the tarball.

**Forked charts: vendor verbatim first, patch second, in separate commits.** The
verbatim commit is the base a future re-vendor diffs against. Squashing the two makes
the next upstream pull a manual merge instead of a re-apply.

**Version numbers diverge from upstream the moment a fork is patched.** Take the next
number in our line; never republish under upstream's own number. The base is recorded
in the release tag message and in the fork notice at the top of the chart's README —
those are the only places it exists, so update both.

**Tag every release** as `<chart>-<version>`, annotated. See README "Release".

## Traps

**`annotations.images` in `Chart.yaml` is a gate, not documentation.** The bundled
`common` library calls `common.errors.insecureImages` from `NOTES.txt`, which compares
every rendered image against that list. How it reacts depends on what the list contains:

- while the list names a bitnami registry (`docker.io/bitnami/`, `bitnamiprem/`,
  `bitnamisecure/`) a substituted image is a hard `fail` — it aborts `helm template` as
  well as `helm install`. That is the upstream state, and it is why repointing the
  images required rewriting the annotation instead of just editing `values.yaml`.
- once the list names our own registry, a further substitution is only a warning.

So the gate no longer stops a mistake here. Keep `annotations.images` in sync with
`values.yaml` anyway: it is what the warning is checked against, and a stale list
reports the wrong images to whoever installs the chart. Update the annotation rather
than setting `global.security.allowInsecureImages` — that flag only silences the check.

**`mongodb-sharded` runs MongoDB 8.0 (LTS) only.** An 8.2 image exists but 8.2 is a
rapid release. It is opt-in per deployment via `image.tag`, never the chart default.
README has the reasoning.

**Images come from a different repo.** All `shepherd9664/*` images are built by
[shepherd44/containers](https://github.com/shepherd44/containers). Changing an image tag
here does nothing until that build exists — check the tag on Docker Hub first.

## Before claiming a chart change works

```shell
helm lint charts/$CHART
helm template t charts/$CHART --set metrics.enabled=true --set volumePermissions.enabled=true
```

The second one matters: the image-verification gate and several images only appear with
those subcharts enabled. Grep the output for `image:` and confirm every one is a tag
that actually exists.

After publishing, verify against the live repo rather than the working tree — add the
Pages URL as a helm repo, `helm pull`, and render the pulled tarball.
