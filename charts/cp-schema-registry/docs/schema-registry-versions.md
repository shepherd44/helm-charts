# Schema Registry versions

The application side: which Confluent Platform version this chart's `imageTag` should
point at, and what changes between lines. For the chart's own history see
[CHANGELOG.md](../CHANGELOG.md).

Everything below was checked against primary sources — Confluent's interoperability
matrix, the `confluentinc/schema-registry` source at each tag, Docker Hub tags, and a
running instance. Dates are as of 2026-09-07.

## Support lifecycle

Each Confluent Platform release ships a specific Apache Kafka version. Confluent Community
support runs two years from the minor release date.

| CP | Kafka | Released | Community EOS | |
|---|---|---|---|---|
| **8.3.x** | 4.3.x | 2026-06-17 | **2027-06-17** | newest — **what this chart pins** |
| 8.2.x | 4.2.x | 2026-03-04 | 2027-03-04 | |
| 8.1.x | 4.1.x | 2025-10-15 | 2026-10-15 | |
| 8.0.x | 4.0.x | 2025-06-11 | 2026-06-11 | **ended** |
| 7.9.x | 3.9.x | 2025-02-19 | 2027-02-19 | pinned by this chart until 1.5.0 |
| 7.8.x | 3.8.x | 2024-12-02 | 2026-12-02 | |
| 7.7.x | 3.7.x | 2024-07-26 | 2026-07-26 | ended |
| 7.6.x | 3.6.x | 2024-02-09 | 2026-02-09 | ended |
| 7.5.x | 3.5.x | 2023-08-25 | 2025-08-25 | ended — chart shipped this until 0.2.0 |

**There is no LTS line.** Confluent designates none — the only `LTS` strings on the
interoperability page are Ubuntu release names and "long-term support versions of Java".
Every minor gets the same flat two years, so the only lever is release date, and picking
a version means picking the newest one you can actually run.

Note 8.0.x: newer than 7.9.x and already out of support. Newer is not automatically
longer-lived — 8.0 released a year before 8.3 and its two years are already up.

Latest patch per line on Docker Hub, as of 2026-09-07: `7.5.16`, `7.6.13`, `7.7.11`,
`7.9.9`, `8.0.7`, `8.1.5`, `8.3.1`.

## Why 8.3.x

8.3.x is simply the line with the most support left — 2027-06-17, against 2027-02-19 for
7.9.x. With no LTS designation to aim at, that is the whole of the argument, and the two
are only four months apart.

The reason to make the move anyway is that the gap only widens: 8.4 will extend it, while
7.9 is the end of the 7.x line and gains nothing further.

### What made it safe

The 7.9 rationale rested on staying with Kafka 3.x clients, because the brokers here are
Kafka 3.5.1 (Strimzi 0.37.0) and 8.3 ships Kafka 4.3 clients. That turned out not to
matter, and it was measured rather than assumed. A throwaway 8.3.1 pod was pointed at the
production brokers with its own `group.id` and its own `_schemas` topic, so neither the
live registry's state nor its consumer group was touched:

| check | result |
|---|---|
| startup against Kafka 3.5.1 brokers | clean, no errors in the log |
| `GET /` | 200 |
| `GET /subjects` | 200 |
| `GET /mode` | `READWRITE` |
| register a schema, then read it back | 200 both ways, identical |

Kafka's protocol is versioned per API and negotiated on connect, so a newer client
downgrades to what the broker offers; 4.x clients dropped support for brokers older than
2.1, which is far behind 3.5.

The other axis is configuration, and it is covered below: **no key registered at 7.5.0 is
gone by 8.3.0** — the surface only grows, 63 keys to 82. So an existing values file cannot
break on the bump.

### What still argues for 7.9.x

The ksqlDB in the same namespaces is 7.9.0. Schema Registry and ksqlDB do not have to
match — ksqlDB reaches Schema Registry over its REST API, which is stable across these
versions — but if you would rather keep the Confluent versions aligned, pin `image.tag`
to `7.9.9` and nothing else about this chart changes.

## Configuration fields

Two sources define what Schema Registry accepts. Both matter here because the chart sets
keys from each:

| Source | File | Covers |
|---|---|---|
| `confluentinc/schema-registry` | `SchemaRegistryConfig.java` | `kafkastore.*`, `leader.*`, `schema.*`, `mode.mutability`, … |
| `confluentinc/rest-utils` | `RestConfig.java` | `listeners`, `ssl.*`, `authentication.*`, `debug`, … |

The lists below come from the `.define(...)` registrations in those files at each tag,
which is the set the process actually accepts — not from release notes, which Confluent
does not publish per version in a retrievable form.

### What this chart sets

| Env the chart injects | Config key | Source |
|---|---|---|
| `SCHEMA_REGISTRY_HOST_NAME` | `host.name` | schema-registry |
| `SCHEMA_REGISTRY_LISTENERS` | `listeners` | rest-utils |
| `SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS` | `kafkastore.bootstrap.servers` | schema-registry |
| `SCHEMA_REGISTRY_KAFKASTORE_GROUP_ID` | `kafkastore.group.id` | schema-registry |
| `SCHEMA_REGISTRY_MASTER_ELIGIBILITY` | `master.eligibility` | schema-registry — **deprecated**, see below |
| `SCHEMA_REGISTRY_HEAP_OPTS` | — | JVM, not a Schema Registry config |
| `SCHEMA_REGISTRY_OPTS` | — | JVM |
| `JMX_PORT` | — | JVM |

Anything in `schema_registry.configurationOverrides` becomes
`SCHEMA_REGISTRY_<KEY_WITH_DOTS_AS_UNDERSCORES>`, uppercased. `customEnv` is passed
through verbatim.

### The fields worth knowing

Of the 71 keys registered at 7.9, these are the ones that come up:

**Kafka store — where schemas actually live**

| Key | Default | Note |
|---|---|---|
| `kafkastore.bootstrap.servers` | — | required; the chart sets it |
| `kafkastore.topic` | `_schemas` | the schema log. This is why pod replacement loses nothing |
| `kafkastore.topic.replication.factor` | `3` | applies only when the topic is created |
| `kafkastore.group.id` | — | leader election group; the chart defaults it to the release name |
| `kafkastore.init.timeout.ms` | `60000` | startup gives up after this |
| `kafkastore.security.protocol`, `kafkastore.sasl.*`, `kafkastore.ssl.*` | — | ~20 keys, mirroring the Kafka client |

**Identity and leader election**

| Key | Note |
|---|---|
| `leader.eligibility` | whether this instance may become the writer. The chart still sets the deprecated `master.eligibility` |
| `host.name` | advertised address; the chart sets it from the pod IP |
| `inter.instance.protocol` | `http`/`https` for forwarding writes to the leader |
| `leader.election.sticky` | added 7.6 |

**Schemas and compatibility**

| Key | Default | Note |
|---|---|---|
| `schema.compatibility.level` | `backward` | global default; per-subject settings override it |
| `mode.mutability` | `true` | whether the registry mode can be changed at runtime |
| `schema.providers` | avro, json, protobuf | schema formats to load |
| `schema.validate.fields` | `false` | added 7.6 |
| `schema.cache.size`, `schema.cache.expiry.secs` | | |

**HTTP layer** (rest-utils)

| Key | Note |
|---|---|
| `listeners` | the chart sets `http://0.0.0.0:<servicePort>` |
| `authentication.method`, `authentication.realm`, `authentication.roles` | there is no auth by default — relevant if you expose an Ingress |
| `ssl.*` | server TLS |
| `debug` | verbose error responses |

**Paging limits** — the newest cluster of additions, and the reason the key count grew:
`schema.search.*`, `subject.search.*` (7.9), `context.search.*`,
`subject.version.search.*` (8.0), each with a `default.limit` and a `max.limit`.

### Added by version

Counts are registered keys, `SchemaRegistryConfig` / `RestConfig`.

| Version | SR | rest-utils | Added |
|---|---|---|---|
| 7.5 | 63 | 79 | baseline |
| 7.6 | 67 | 84 | SR: `enable.fips`, `init.resource.extension.class`, `leader.election.sticky`, `schema.validate.fields` · rest: `sni.check.enabled`, `network.traffic.rate.limit.*`, `metrics.global.stats.request.tags.enable` |
| 7.7 | 68 | 84 | SR: `enable.store.health.check` |
| 7.8 | 68 | 84 | none |
| 7.9 | 71 | 86 | SR: `kafkastore.init.wait.for.reader`, `subject.search.default.limit`, `subject.search.max.limit` · rest: `access.control.expose.headers`, `hsts.header.enable` |
| 8.0 | 75 | 91 | SR: `context.search.*`, `subject.version.search.*` · rest: `expected.sni.headers`, `prefix.sni.check.enabled`, `sni.host.check.enabled`, `percentile.max.latency.ms`, `network.forwarded.request.customizer.enable` |
| 8.1 | 75 | 94 | rest only: `prefix.sni.prefix`, `ssl.spire.enabled`, `return.429.instead.of.500.for.jetty.response.errors` |
| 8.2 | 78 | 99 | SR: `associations.enable`, `enable.fips.mode`, `schema.validate.new.schemas` · rest: `dos.filter.tenant.*`, `jetty.legacy.uri.compliance`, `disable.response.size.metrics.collection` |
| 8.3 | 82 | 100 | SR: `metadata.encoder.secret.strict.validation`, `schema.reject.empty.subject`, `size.limit.filter.enabled`, `size.limit.filter.max.request.body.size` · rest: `proxy.protocol.accepted.ip.range` |

### Removed by version

**None.** Across 7.5.0 → 8.3.0, neither `SchemaRegistryConfig` nor `RestConfig` drops a
single registered key — 63 → 82 and 79 → 100, additions only. Nothing this chart sets is
at risk anywhere in that range, including across the 7.x → 8.x major boundary.

That is the useful result for upgrade planning: on this axis a version bump cannot break
an existing config. What 8.x does change is the Kafka client generation and the
recommended JRE, not the configuration surface.

### Deprecated, still accepted

Marked `@Deprecated` in 8.3.0 source but still registered and still working:

| Deprecated | Use instead |
|---|---|
| `master.eligibility` | `leader.eligibility` |
| `avro.compatibility.level` | `schema.compatibility.level` |
| `kafkastore.connection.url` | `kafkastore.bootstrap.servers` |
| `schema.registry.resource.extension.class` | `resource.extension.class` |
| `schema.registry.inter.instance.protocol` | `inter.instance.protocol` |
| `ssl.client.auth` (rest-utils) | `ssl.client.authentication` |

**The chart sets none of these.** It emitted `SCHEMA_REGISTRY_MASTER_ELIGIBILITY` until
0.5.0 and now emits `leader.eligibility`, from the `leaderEligibility` value. A values
file that sets `master.eligibility` under `configurationOverrides` still wins, and the
chart then stops emitting the new key so the two cannot both be set — the deprecated
spelling still works at 8.3.1, verified, but it is worth moving off.

`kafkastore.connection.url` is the ZooKeeper-era store address. Its continued presence is
a compatibility shim, not an option worth using.

## Runtime

The 8.3.1 image runs Temurin **25** — verified inside the image:

```
openjdk version "25.0.3" 2026-04-21 LTS
OpenJDK Runtime Environment Temurin-25.0.3+9 (build 25.0.3+9-LTS)
```

The 7.9.9 image it replaces ran Temurin 17. The images carry their own JRE, so the jump
only matters if you build on top of them; it does not change the container's memory
behaviour, since 17 was already cgroup v2 aware.

That JVM is cgroup v2 aware, so it reads a container memory limit correctly — **when one
exists**. With none, it sizes from the node. Measured on a 257Gi node:

```
/sys/fs/cgroup/memory.max  ->  max
MaxRAMPercentage           =  25.0
MaxHeapSize                =  32178700288   (30GiB)
actual usage               =  288Mi
```

With a 1Gi limit the same JVM reports a 256Mi max heap. Set `resources.limits.memory`
whenever you set `heapOptions`, and keep `-Xmx` below the limit — exceeding it gets the
pod OOMKilled rather than raising `OutOfMemoryError`.

## Upgrading

Schema Registry keeps its state in the `_schemas` Kafka topic, not on disk, so replacing
pods does not lose schemas and rollback is cheap. A version bump is:

1. Change `image.tag`.
2. Roll dev, check `/` and `/subjects` respond and the subject count is unchanged.
3. Roll prod.

Two things worth checking on any bump, because they are what this chart depends on rather
than what release notes emphasise: that the `SCHEMA_REGISTRY_*` env contract still holds
(the config diff above is how to tell), and that the image's JRE still sizes its heap the
way your limits assume.

## Sources

- [Supported versions and interoperability](https://docs.confluent.io/platform/current/installation/versions-interoperability.html) — the lifecycle table
- [`confluentinc/schema-registry`](https://github.com/confluentinc/schema-registry) — `core/src/main/java/io/confluent/kafka/schemaregistry/rest/SchemaRegistryConfig.java` at each tag, for the config diffs
- [`confluentinc/cp-schema-registry`](https://hub.docker.com/r/confluentinc/cp-schema-registry/tags) — available tags

The Schema Registry image is under the Confluent Community License, not Apache-2.0. Fine
for internal use; it restricts offering it as a competing managed service.
