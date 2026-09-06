# Helm Charts

A Helm chart repository, published as signed OCI artifacts to GitHub Container Registry.

| | |
|---|---|
| Registry | `oci://ghcr.io/shepherd44/charts` |
| Signing | keyless cosign, issuer `token.actions.githubusercontent.com` |
| Source | <https://github.com/shepherd44/helm-charts> |
| Pages repo (frozen) | `https://shepherd44.github.io/helm-charts/docs` — see below |

There is no repo to add and no marketplace listing: an OCI reference is the address.
Nothing needs to be installed on the cluster to use it.

## Use

Charts are published to GitHub Container Registry, signed. No repo to add:

```shell
helm install my-release oci://ghcr.io/shepherd44/charts/cp-schema-registry --version 1.3.0
helm show values oci://ghcr.io/shepherd44/charts/cp-schema-registry --version 1.3.0
```

### The Pages repo, frozen

The static repo below still serves everything published up to and including
`cp-schema-registry` 1.3.0 and `mongodb-sharded` 9.4.17. Nothing new is added to it —
those files stay so that pinned installs keep resolving, and new versions go to the
registry only.

```shell
helm repo add shepherd44 https://shepherd44.github.io/helm-charts/docs
helm repo update shepherd44

helm search repo shepherd44            # what is available
helm search repo shepherd44 --versions # every published version
```

Install, pinning the chart version so a later release cannot change a deployment
underneath you:

```shell
helm install my-release shepherd44/mongodb-sharded \
  --version 9.4.17 \
  --namespace my-namespace --create-namespace \
  -f my-values.yaml
```

```shell
helm upgrade my-release shepherd44/mongodb-sharded --version <new> -f my-values.yaml
helm uninstall my-release
```

Each chart's own README documents its values and a working install for that chart.

### Moving a release off the Pages repo

Helm, in place:

```shell
helm upgrade my-release oci://ghcr.io/shepherd44/charts/cp-schema-registry \
  --version 1.3.0 --reuse-values
```

Argo CD — the `chart` and values stay as they are, only the source changes:

```yaml
sources:
  - repoURL: ghcr.io/shepherd44/charts    # was https://shepherd44.github.io/helm-charts/docs
    chart: cp-schema-registry
    targetRevision: 1.3.0
    helm:
      releaseName: cp-schema-registry
      valueFiles: [...]
```

Argo CD needs the repository registered as a Helm repo of type OCI; on versions before
3.0 that is the `enableOCI: true` flag on the repository entry. The registry is public,
so no credentials.

### Verifying a chart

Every release in the registry is signed with keyless cosign — the signing identity is
this repo's release workflow, recorded in Sigstore's public transparency log, so there is
no key to fetch:

```shell
cosign verify ghcr.io/shepherd44/charts/cp-schema-registry:1.3.0 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github.com/shepherd44/helm-charts/'
```

Versions that exist in both channels are the same bytes: through 1.3.0 the workflow
pushed the very `.tgz` committed in `docs/` rather than building the chart again.

## Charts

| chart | app | install notes |
|---|---|---|
| [`cp-schema-registry`](charts/cp-schema-registry/README.md) | Confluent Schema Registry 7.9 | needs an existing Kafka; the upstream confluent chart is gone, this is the only copy |
| [`cp-ksql-server`](charts/cp-ksql-server/README.md) | Confluent ksqlDB 7.9 | needs an existing Kafka; vendored from the same deleted confluent repo, **not published yet** |
| [`mongodb-sharded`](charts/mongodb-sharded/README.md) | MongoDB 8.0 | fork of `bitnami/mongodb-sharded`, images from [shepherd44/containers](https://github.com/shepherd44/containers) |
| [`common`](charts/common/README.md) | — | bitnami library chart, dependency of `mongodb-sharded`, not published |

Each chart README has an install section with a values file worth starting from, and a
`CHANGELOG.md` at the chart root covering that chart's releases here.

A forked chart takes over that file rather than adding a second one beside it. This is
what forks actually do — OpenTofu, OpenSearch and OpenBao all own their upstream's
`CHANGELOG.md` — and the alternatives are not conventions: a GitHub-wide search finds one
repository using `CHANGELOG.fork.md` and none using `CHANGELOG.downstream.md`.

Upstream's entries are kept in the same file, below the fork's, under a heading that says
whose they are. Re-vendoring a later upstream release means merging their new entries into
that lower section, which is a conflict worth having: it happens exactly when someone is
already reading upstream's changes.

### mongodb-sharded: which MongoDB series

The chart defaults to the latest **8.0** patch, currently `8.0.30-debian-12-latest`.
8.0 is the LTS series; that is the only series this chart is expected to run.

An 8.2 image is built alongside it, but 8.2 is a rapid release, not LTS. Use it only
by naming it explicitly, per deployment:

```shell
--set image.tag=8.2.12-debian-12-latest
```

Do not make 8.2 the chart default. The chart's `appVersion` and `annotations.images`
track 8.0, so an 8.2 override is reported as a retagged image in NOTES (a warning, not
a failure). Upstream never shipped an 8.2 chart line either — bitnami's
`mongodb-sharded` chart has been pinned to appVersion 8.0.13 since 2025-08-25.

8.0 -> 8.2 is a data upgrade, not a tag swap: it needs an FCV bump and a rollout in
config server -> shard data -> mongos order.

Bumping the 8.0 patch is a two-step change: raise `version` in the
[containers workflow matrix](https://github.com/shepherd44/containers/blob/main/.github/workflows/mongodb-sharded.yml),
then point `image.tag` and `appVersion` here at the new build.

### mongodb-sharded: images

Bitnami moved its public catalog to `bitnamilegacy` and stopped updating it, so every
image this chart references is built in
[shepherd44/containers](https://github.com/shepherd44/containers) instead. No
`bitnamilegacy` image is left.

| values path | image | what it is |
|---|---|---|
| `image` | `shepherd9664/mongodb-sharded` | bitnami scaffolding, `mongod`/`mongos` replaced by the official MongoDB debian12 build |
| `volumePermissions.image` | `shepherd9664/os-shell` | minideb plus the same shell tooling, minus four bitnami helper binaries with no upstream source |
| `metrics.image` | `shepherd9664/mongodb-exporter` | Percona's official release binary at the path the chart calls |

Changing a tag here does nothing until that build exists — check Docker Hub first.

When you repoint an image, update `annotations.images` in `Chart.yaml` to match. The
bundled `common` library checks every rendered image against that list. On the upstream
chart, whose list names `docker.io/bitnami/*`, a substituted image is a hard failure —
which is why the fork had to rewrite the annotation rather than only edit `values.yaml`.
Now that the list names our own registry, a mismatch is a warning rather than an error,
so nothing will stop a stale annotation; keep it honest by hand. Setting
`global.security.allowInsecureImages` only silences the check and is not the fix.

## Checks

CI runs on every pull request (`.github/workflows/ci.yaml`) and is the same set of
commands worth running locally before pushing:

```shell
CHART=cp-schema-registry

helm lint charts/$CHART
helm template t charts/$CHART --set metrics.enabled=true --set volumePermissions.enabled=true
helm unittest charts/$CHART                    # helm plugin install https://github.com/helm-unittest/helm-unittest
helm template t charts/$CHART --kube-version 1.22.0 | kubeconform -strict -summary \
  -kubernetes-version 1.22.0 -ignore-missing-schemas
```

What CI adds on top:

- `ct lint`, which **fails a PR that changes a chart without bumping its version** — the
  mechanical form of "a published version is immutable".
- `ct install` on KinD at the declared Kubernetes floor and at a current version, against
  a single-node Kafka deployed from `.github/ci/kafka.yaml`, followed by `helm test`.
  The values it installs are `charts/<chart>/ci/*-values.yaml`.
- The same lint and render under both the Helm 3 and Helm 4 clients.
- `release-verify.yaml`, on any change under `docs/`: every version in `index.yaml` has
  its `.tgz`, every digest matches the file, and no already-published version's digest
  changed. Run it yourself with `python3 hack/verify-index.py docs`.

Template unit tests live in `charts/<chart>/tests/*_test.yaml`; neither they nor `ci/`
are packaged.

## Release

Publishing is the tag. There is nothing to build by hand and nothing to commit:

```shell
CHART=cp-schema-registry
VERSION=$(awk '/^version:/{print $2}' charts/$CHART/Chart.yaml)

git tag -a $CHART-$VERSION -m "..."
git push origin $CHART-$VERSION
```

That fires `release-oci.yaml`, which packages the chart from the tag, pushes it to
`ghcr.io/shepherd44/charts`, signs it with keyless cosign and verifies its own output.
It refuses a tag whose version does not match the chart's `Chart.yaml`, so a mistyped tag
fails instead of publishing something surprising.

Tags are `<chart>-<version>` because this repo holds more than one chart. The tag message
records what the release is; for a forked chart it also records the upstream version and
commit it was based on, and the local changes applied on top.

A package pushed to ghcr.io for the first time is **private**. Make it public once, under
the account's Packages settings, or `helm pull oci://...` fails with a 401 for everyone
else.

### docs/ is frozen

It holds real artifacts people have pulled, so it stays exactly as it is. `helm repo
index` is not run any more and no `.tgz` is added or changed. `release-verify.yaml` still
runs on any change under `docs/` and fails if a published digest or `created` timestamp
moves — which now means it guards against edits rather than checking a release.

Republishing an old version from that repo is what `hack/verify-index.py` prevents; run
it locally the same way CI does:

```shell
git show origin/main:docs/index.yaml > /tmp/base-index.yaml
python3 hack/verify-index.py docs --baseline /tmp/base-index.yaml
```

## Versioning a forked chart

`mongodb-sharded` is a fork, so its version number has to come from somewhere. The rule
here:

- Vendor upstream verbatim first, keeping upstream's own version. That commit is the base.
- Every local change takes the next number in **our** line. 9.4.15 was the last shared
  number; from 9.4.16 on, the line is ours and no longer lines up with bitnami's.
- Do not reuse upstream's version for a chart carrying local changes. Two different charts
  with one version number is the thing that actually breaks people.

Because the numbers diverge, the base has to be written down rather than inferred. It
lives in two places: the release tag message, and the fork notice at the top of the
chart's own README.

To pick up a later bitnami release: re-vendor that version as a standalone commit,
re-apply the local diff on top, update the fork notice and the tag message with the new
base, and publish as the next number in our line.

## License

Every chart here is a fork, and all of them are Apache-2.0.

`mongodb-sharded` and `common` come from
[bitnami/charts](https://github.com/bitnami/charts). `cp-schema-registry` and
`cp-ksql-server` both come from `confluentinc/cp-helm-charts`, a repository since deleted
from GitHub; its `LICENSE` is kept in each chart directory, recovered verbatim from a
surviving fork, because upstream shipped no per-chart copy.

Each chart directory keeps upstream's license file, and the fork notice at the top of the
chart's README records the base version, the base commit, and every local change — which
is what Apache-2.0 section 4(b) asks for.
