# Schema Registry versions

The application side: which Confluent Platform version this chart's `imageTag` should
point at, and what changes between lines. For the chart's own history see
[CHANGELOG.md](CHANGELOG.md).

Everything below was checked against primary sources — Confluent's interoperability
matrix, the `confluentinc/schema-registry` source at each tag, Docker Hub tags, and a
running instance. Dates are as of 2026-09-05.

## Support lifecycle

Each Confluent Platform release ships a specific Apache Kafka version. Confluent Community
support runs two years from the minor release date.

| CP | Kafka | Released | Community EOS | |
|---|---|---|---|---|
| 8.3.x | 4.3.x | 2026-06-17 | 2027-06-17 | newest |
| 8.2.x | 4.2.x | 2026-03-04 | 2027-03-04 | |
| 8.1.x | 4.1.x | 2025-10-15 | 2026-10-15 | |
| 8.0.x | 4.0.x | 2025-06-11 | 2026-06-11 | **ended** |
| **7.9.x** | 3.9.x | 2025-02-19 | **2027-02-19** | **what this chart pins** |
| 7.8.x | 3.8.x | 2024-12-02 | 2026-12-02 | |
| 7.7.x | 3.7.x | 2024-07-26 | 2026-07-26 | ended |
| 7.6.x | 3.6.x | 2024-02-09 | 2026-02-09 | ended |
| 7.5.x | 3.5.x | 2023-08-25 | 2025-08-25 | ended — chart shipped this until 0.2.0 |

Note 8.0.x: newer than 7.9.x and already out of support. Newer is not automatically
longer-lived.

Latest patch per line on Docker Hub, as of 2026-09-05: `7.5.16`, `7.6.13`, `7.7.11`,
`7.9.9`, `8.0.7`, `8.1.5`, `8.3.1`.

## Why 7.9.x

- 7.5.x support ended over a year ago.
- 7.9.x runs to 2027-02-19, longer than 8.0.x and 8.1.x.
- The ksqlDB in the same namespaces is already 7.9.0, so the Confluent versions line up.
- It stays on Kafka 3.x clients. The brokers here are Kafka 3.5.1 (Strimzi 0.37.0); 8.x
  would bring Kafka 4.x clients for no benefit yet.

Moving to 8.x is a real decision, not a tag bump: Kafka 4.x clients, Java 21 recommended,
and 8.2.x or 8.3.x rather than 8.0.x since that line has already ended.

## What actually changes between versions

Schema Registry's configuration surface only grows across these lines. Comparing
`SchemaRegistryConfig.java` at each tag:

**7.5.7 → 7.9.9** — 15 properties added, **none removed**:

```
cert.name                          kafkastore.init.wait.for.reader
cert.type                          size.limit.filter.enabled
context.search.default.limit       size.limit.filter.max.request.body.size
context.search.max.limit           subject.search.default.limit
enable.fips                        subject.search.max.limit
enable.store.health.check          subject.version.search.default.limit
init.resource.extension.class      subject.version.search.max.limit
```

**7.9.9 → 8.3.1** — 5 properties added, **none removed**:

```
associations.enable                schema.reject.empty.subject
enable.fips.mode                   schema.validate.new.schemas
metadata.encoder.secret.strict.validation
```

So nothing this chart sets is at risk across the whole 7.5 → 8.3 range. Specifically, all
of these still exist at 8.3.1:

| Key | 7.5.7 | 7.9.9 | 8.3.1 |
|---|---|---|---|
| `kafkastore.bootstrap.servers` | yes | yes | yes |
| `kafkastore.group.id` | yes | yes | yes |
| `host.name` | yes | yes | yes |
| `master.eligibility` | yes | yes | yes |
| `leader.eligibility` | yes | yes | yes |

`master.eligibility` is the deprecated spelling of `leader.eligibility`, and the chart
still sets `SCHEMA_REGISTRY_MASTER_ELIGIBILITY`. Both remain accepted at 8.3.1, so this is
not urgent, but new deployments should prefer the `leader` spelling.

The JMX MBean the exporter config scrapes, `kafka.schema.registry:type=master-slave-role`,
is also unchanged through 8.3.1 despite how it reads.

## Runtime

The 7.9.9 image runs Temurin **17** — verified inside a running container:

```
openjdk version "17.0.20" 2026-07-21
OpenJDK Runtime Environment Temurin-17.0.20+8
```

Confluent's recommendation is Java 17 for 7.9.x and Java 21 for 8.x; the images carry
their own JRE, so this only matters if you build on top of them.

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

1. Change `schema_registry.imageTag`.
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
