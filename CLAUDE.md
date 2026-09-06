# CLAUDE.md

A Helm chart repository published as signed OCI artifacts to GHCR. `README.md` is the
human-facing document; this file is the part an agent gets wrong without being told.

## Layout

```
charts/<name>/     chart sources — the thing you edit
charts/common/     bitnami library chart, dependency only, never published on its own
docs/              the retired GitHub Pages repo, frozen — read Rules before touching it
```

**Charts are published to `oci://ghcr.io/<owner>/charts` and nowhere else.** Nothing here
is packaged by hand: pushing a git tag `<chart>-<version>` runs `release-oci.yaml`, which
packages the chart, pushes it to GHCR, signs it with keyless cosign, and verifies the
signature before it finishes. The tag is the release; there is no publish step to run
locally and no artifact to commit.

`docs/` was that channel until `cp-schema-registry` 1.3.0 and is now frozen. Do not add to
it, do not regenerate `index.yaml`, do not delete what is there — pinned installs still
resolve against it. Everything about editing it is under Rules.

## Work in a worktree

**Every change — code, chart, docs — happens in a worktree, never in the primary
checkout.** A sibling `<repo>-wt/<branch>/` directory, derived from the repo rather than
written out, so this works from any clone on any machine:

```shell
BR=<type>/<short-name>                          # feat, fix, chore, docs
ROOT=$(cd "$(git rev-parse --git-common-dir)/.." && pwd)
WT="$ROOT/../$(basename "$ROOT")-wt/$BR"

git fetch -q origin
git worktree add -b "$BR" "$WT" origin/main
cd "$WT"
```

`--git-common-dir`, not `--show-toplevel`: run from inside an existing worktree the
latter returns that worktree, and the sibling path nests inside itself. The common dir is
the primary checkout's `.git` from anywhere in the repo, so this resolves the same way
whether it runs from the primary checkout or from another worktree.

Branch from `origin/main`, not from local HEAD. `git worktree add` takes whatever ref it
is handed, and the primary checkout is often parked on something unrelated — that is the
mistake this line exists to prevent, so keep the explicit `origin/main` and the `fetch`
before it.

The path is a sibling of the repo, not inside it: several worktrees can exist at once,
the directory mirrors the branch name, and nothing lands under the repo where it could be
committed by accident.

Clean up once the branch is merged — a leftover worktree is a second checkout of the same
repo quietly going stale:

```shell
git worktree remove "$WT"
git branch -d "$BR"
git worktree list          # confirm only the primary checkout remains
```

Nothing is packaged in the worktree. A chart change is source only — bump
`Chart.yaml`'s `version`, merge, then push the `<chart>-<version>` tag and let
`release-oci.yaml` build and sign the artifact. The tag has to be pushed from a commit on
`main`, and the workflow refuses if the tag's version and `Chart.yaml` disagree.

## Rules

**A published version is immutable.** `docs/` holds real artifacts people may have
pulled. Never repackage an existing version with different content — bump the version.
Deleting a published `.tgz` is only acceptable for a release that was live briefly and
is superseded, and it needs saying out loud in the commit.

**`docs/` is frozen.** It stops at `cp-schema-registry` 1.3.0 and `mongodb-sharded`
9.4.17. Charts are published to `ghcr.io/shepherd44/charts` now; nothing new is added to
`docs/` and `helm repo index` is not run any more. The files stay so pinned installs keep
resolving. `release-verify.yaml` still runs on any change under `docs/`, which now means
it guards the frozen files rather than checking a release.

**Do not regenerate the index.** `docs/index.yaml` is frozen with the rest of that
directory. If it ever has to be rebuilt, `--merge` alone does not stop `created` churn —
it regenerates the entry for every `.tgz` still there — so the restore step is not
optional:

```shell
git show HEAD:docs/index.yaml > /tmp/base-index.yaml
helm repo index docs --url https://shepherd44.github.io/helm-charts/docs --merge docs/index.yaml
python3 hack/verify-index.py docs --baseline /tmp/base-index.yaml --restore-created
```

The same script without `--restore-created` is the check: it fails on a changed digest or
a changed `created` for an already-published version, and `release-verify.yaml` runs it on
any PR touching `docs/`.

**Run `helm dependency update` before packaging** any chart with dependencies. The
release workflow does this itself; it matters for local `helm package` and lint.
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

**The tag is the release.** Pushing `<chart>-<version>`, annotated, runs
`release-oci.yaml`: it packages the chart from the tag, pushes it to
`ghcr.io/shepherd44/charts` and signs it with keyless cosign. Nothing is committed, and
there is no packaging step to do by hand. It fails if the tag version and `Chart.yaml`
disagree. Never move a release tag — the artifact it produced is immutable.

A version that still exists in `docs/` is pushed from that file rather than rebuilt:
`helm package` embeds a timestamp, so rebuilding would change the digest of something
already published.

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

A fresh worktree has no built dependencies — `charts/mongodb-sharded/charts/common-*.tgz`
is gitignored — so **`helm dependency update` comes first, before lint, not just before
packaging.** Without it `helm lint charts/mongodb-sharded` fails on a `common.*` template
include, which looks like a chart bug and is not one.

Then lint and render with that chart's optional pieces switched on: several images and
the image-verification gate only appear then. The flags differ per chart; there is no
generic set.

```shell
helm dependency update charts/mongodb-sharded
helm lint charts/mongodb-sharded
helm template t charts/mongodb-sharded \
  --set metrics.enabled=true --set volumePermissions.enabled=true
```

```shell
helm lint charts/cp-schema-registry
helm template t charts/cp-schema-registry \
  --set schema_registry.kafka.bootstrapServers=PLAINTEXT://kafka:9092 \
  --set schema_registry.prometheus.jmx.enabled=true \
  --set schema_registry.ingress.enabled=true \
  --set 'schema_registry.ingress.hosts[0].host=sr.example.com' \
  --set 'schema_registry.ingress.hosts[0].paths[0].path=/'
```

**`--set` on a key a chart does not have is accepted silently.** Reusing one chart's
flags on the other renders plain defaults and exits zero, which reads exactly like a
passing check. `cp-schema-registry` nests everything under `schema_registry`, so
`metrics.enabled=true` does nothing there — one image in the output instead of two.

`charts/common` is a library chart: `helm lint` works, `helm template` fails with
"library charts are not installable". Expected, not a regression.

Grep the output for `image:` and confirm every tag actually exists on Docker Hub.

Those per-chart flags are not typed out in the workflow. `.github/workflows/ci.yaml`
names no chart at all: what CI needs to know about one lives in
`.github/ci/<chart>.env`, sourced with `$CHART` set to the chart's path. It is outside
the chart directory because ct treats any file that changes under `charts/<name>/` as a
chart change and demands a version bump — a CI-only edit should not force a release.

```shell
RENDER_ARGS=(-f "$CHART/ci/metrics-values.yaml" --set metrics.enabled=true)
INSTALL=true                                    # run `ct install` on kind
FIXTURES=(.github/ci/kafka.yaml)                # applied first
FIXTURE_WAIT=(-n kafka rollout status deployment/kafka --timeout=300s)
```

Every variable is optional. **A chart with no env file is rendered with plain defaults
and is never installed**, which is the safe default and also a silent one: leaving
`INSTALL=true` out does not fail anything, it just means nothing was ever installed. Say
out loud which of the two a new chart is getting.

After publishing, verify against what was actually published rather than the working
tree:

```shell
helm pull oci://ghcr.io/<owner>/charts/$CHART --version $VERSION
cosign verify oci://ghcr.io/<owner>/charts/$CHART:$VERSION \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github.com/<owner>/helm-charts/'
```

Then render the pulled tarball with the values a real deployment uses. The release
workflow already runs `cosign verify` on the digest it just pushed, so a green run means
the artifact is signed; repeating it here is about confirming the *tag* resolves to that
artifact.
