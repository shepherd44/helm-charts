# Helm Charts

Charts published through GitHub Pages at <https://shepherd44.github.io/helm-charts/docs>.

## Use

```shell
helm repo add shepherd44 https://shepherd44.github.io/helm-charts/docs
helm repo update
helm search repo shepherd44
```

## Charts

| chart | app | notes |
|---|---|---|
| `cp-schema-registry` | Confluent Schema Registry | |
| `mongodb-sharded` | MongoDB 8.0 | fork of `bitnami/mongodb-sharded`, images from [shepherd44/containers](https://github.com/shepherd44/containers) |
| `common` | — | bitnami library chart, dependency only, not published |

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

## Release

```shell
CHART=mongodb-sharded
VERSION=$(awk '/^version:/{print $2}' charts/$CHART/Chart.yaml)

# charts with dependencies only
helm dependency update ./charts/$CHART

helm package ./charts/$CHART --destination docs
helm repo index docs --url https://shepherd44.github.io/helm-charts/docs --merge docs/index.yaml
```

`--merge` keeps the `created` timestamps of charts this release did not touch.
A published `.tgz` is immutable: to change a chart, bump its version rather than
repackaging one that is already live.

Then commit `docs/` and push to `main`. GitHub Pages serves the repo root of `main`,
so `docs/index.yaml` is live once the Pages build finishes.

Tag the release commit:

```shell
git tag -a $CHART-$VERSION -m "..."
git push origin $CHART-$VERSION
```

Tags are `<chart>-<version>` because this repo holds more than one chart. The tag
message records what the release is; for a forked chart it also records the upstream
version and commit it was based on, and the local changes applied on top.

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

`mongodb-sharded` and `common` are forks of
[bitnami/charts](https://github.com/bitnami/charts), Apache-2.0. Each chart directory
keeps upstream's `LICENSE.md`, and the fork notice at the top of the chart's README
records the base version, the base commit, and every local change — which is what
Apache-2.0 section 4(b) asks for.
