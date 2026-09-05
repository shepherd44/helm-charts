# Chart changelog

This fork's version line. The `CHANGELOG.md` at the chart root is **bitnami's**, vendored
along with the rest of the chart and last covering their 9.4.14 — it does not know about
anything below.

Each release is tagged in git as `mongodb-sharded-<version>`.

The fork notice at the top of [the chart README](../README.md) always names the upstream
version and commit the current release is based on.

## 9.4.17

- `volumePermissions.image`: `bitnamilegacy/os-shell:12-debian-12-r51` →
  `shepherd9664/os-shell:12-debian-12-latest`
- `metrics.image`: `bitnamilegacy/mongodb-exporter:0.47.0-debian-12-r1` →
  `shepherd9664/mongodb-exporter:0.53.0-debian-12-latest`

No image in the chart comes from a frozen registry any more. Both replacements are built
in [shepherd44/containers](https://github.com/shepherd44/containers): `os-shell` is
minideb with the same shell tooling minus four bitnami helper binaries that have no
upstream source, and `mongodb-exporter` is Percona's own release binary at the path the
chart calls.

The exporter jump is 0.47.0 → 0.53.0. Two things change in what it emits, both verified by
running both versions against the same mongos and diffing `/metrics`:

- `mongodb_mongod_replset_my_state` disappears **on mongos**. 0.47 reported `set=""`,
  value `6` (UNKNOWN) on a router that is not a replica set member; upstream removed it.
  mongod — config servers and shards — still report it.
- `mongodb_indexstats_accesses_ops` gains a `shard` label. The same `collection` +
  `key_name` from different shards used to collapse into one series.

## 9.4.16

- `image`: `bitnami/mongodb-sharded:8.0.13-debian-12-r0` →
  `shepherd9664/mongodb-sharded:8.0.30-debian-12-latest`
- `volumePermissions.image`, `metrics.image`: `bitnami/*` → `bitnamilegacy/*`, tags
  unchanged
- `common` dependency: `oci://registry-1.docker.io/bitnamicharts` → `file://../common`,
  vendored in this repo
- `appVersion`: 8.0.13 → 8.0.30
- `annotations.images` rewritten to list the substituted images

That last one is not cosmetic. The bundled `common` library calls
`common.errors.insecureImages`, which compares every rendered image against
`annotations.images` and **fails the release** while that list names a bitnami registry.
Repointing images without rewriting the annotation produces a chart that cannot install.

**Pulled from the repo index.** It was published for about twenty minutes, and the only
thing distinguishing it is the `bitnamilegacy` images that 9.4.17 retires. The tarball is
gone; the version number is not reused.

## 9.4.15

Upstream, vendored verbatim from
[bitnami/charts](https://github.com/bitnami/charts) at commit `8f8032ba`, with no local
changes. Never published — it exists as the commit that later releases diff against.

`common` 2.31.10 was vendored in the same commit.

Bitnami had already moved its public container catalog to `bitnamilegacy` and stopped
updating it, which is why the chart needed forking rather than consuming.

## Versioning

9.4.15 is the last version number shared with bitnami. From 9.4.16 the line is ours and
does not track theirs — a version here is not the same chart as the version with that
number upstream.

To pick up a later bitnami release: vendor it verbatim as its own commit, re-apply the
local diff on top, update the fork notice and the tag message with the new base, and
publish as the next number in this line.
