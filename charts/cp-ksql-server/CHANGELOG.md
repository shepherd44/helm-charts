# Changelog

Chart versions of `cp-ksql-server`. The chart's own line, not Confluent's.

Forked from `confluentinc/cp-helm-charts`, a repository that no longer exists, so there is
no upstream changelog to keep alongside this one. What was vendored is the copy the live
`cp-ksqldb-server` release ran from, already at `0.1.1`; this line restarts at 1.0.0 — see
the fork notice in [README.md](README.md).

Each release is tagged in git as `cp-ksql-server-<version>`.

## 1.5.0

- **Default image is `8.3.1`** (Confluent Platform 8.3.x), up from `7.9.9`. Nothing else
  in the chart changes.

  Confluent designates no LTS line — every minor gets a flat two years of Community
  support — so the choice is only which line has the most left: 8.3.x to 2027-06-17
  against 7.9.x to 2027-02-19. ksqlDB is still a shipped component in 8.x; it was not
  deprecated or removed.

  **Read this before rolling a server that has persistent queries.** Unlike Schema
  Registry, whose whole state is the `_schemas` topic, a ksqlDB server owns a command
  topic of serialized query plans plus a changelog topic and a RocksDB state store per
  query. A version bump replays those plans.

  Two things in the 8.x line bear on that, both from Confluent's
  [ksqlDB upgrade guide](https://docs.confluent.io/platform/current/ksqldb/upgrading.html):

  - `KStream.transformValues()` was removed in Apache Kafka 4.0, so ksqlDB 8.0.0 moved to
    `processValues()`. **With the "merge repartition topics" optimization — which is on by
    default — 8.0.0 is unsafe.** The fix landed in 8.0.1. Anything at or above that,
    including the 8.3.1 pinned here, is clear of it, but do not stop at 8.0.0.
  - The Kafka Log4j appender is deprecated from 8.0.x, so Log4j properties that use it
    stop working. This chart sets no Log4j configuration and neither does the live
    deployment — checked, the container env is `KSQL_*` only — so nothing here is
    affected.

  Compatibility with the Kafka 3.5.1 brokers here (Strimzi 0.37.0) was measured rather
  than assumed, since 8.3 ships Kafka 4.3 clients. An 8.3.1 server with its own
  `ksql.service.id`, and so its own command topic, was pointed at those brokers:

  | check | result |
  |---|---|
  | `/info` | `serverStatus: RUNNING`, version 8.3.1 |
  | `/healthcheck` | `isHealthy: true` — metastore, kafka, commandRunner |
  | `CREATE STREAM` over a new topic | success |
  | `CREATE STREAM AS SELECT ... PARTITION BY` | `RUNNING` — exercises a repartition topic |
  | `CREATE TABLE AS SELECT ... GROUP BY` | `RUNNING` — exercises a state store and its changelog |
  | server log | no Kafka protocol errors; the only `ERROR` lines are the Confluent version check failing to resolve `version-check.confluent.io`, which egress blocks on 7.9.9 too |

  Kafka negotiates per-API versions on connect and 4.x clients still support brokers back
  to 2.1. The probe's topics and its Strimzi `KafkaTopic` resources were removed afterwards.

  What that probe does **not** cover is replaying an existing 7.9.9 command topic, because
  it ran on a service id of its own. That is the part to rehearse per deployment, against a
  copy, before rolling a server with live queries.

- **This file.** Versions before 1.5.0 are reconstructed below from their release commits
  and the `artifacthub.io/changes` annotation each of them shipped.

## 1.4.0

- **JMX rules that match a bean that exists.** The inherited config looked for
  `type=ksql-engine-query-stats`, which ksqlDB has never registered, so the exporter had
  only ever served its own four metrics.
- **`ksql.advertised.listener` is set to the pod IP**, so servers can reach each other.
  ksqlDB otherwise advertises a Deployment pod's hostname, which is not in DNS.
- The probe rationale in `values.yaml` and the README described `/healthcheck` as
  permanently unhealthy; that was stale state which cleared on restart.

## 1.3.0

- **JMX exporter is `shepherd9664/jmx-exporter` 1.6.0**, replacing a 2018 image that only
  ran because it was still JDK 8.
- **ServiceMonitor, PodMonitor and PrometheusRule** for the Prometheus Operator, which is
  what actually scrapes — the `prometheus.io` annotations never did.
- **Ingress and HTTPRoute** for the REST API, both off by default.
- The JMX config uses `includeObjectNames`, the spelling jmx_exporter 1.x understands.
  Metric names are unchanged.

## 1.2.0

- **Values layout**: `image` is a map, `servicePort` moved to `service.port`,
  `prometheus.jmx` became `metrics`, `cp-schema-registry` became `schemaRegistry`. The old
  names still work, apart from a bare `image` string.
- **ServiceAccount, PodDisruptionBudget**, `commonLabels`/`commonAnnotations` and
  per-resource metadata.
- Pod and container security contexts, `topologySpreadConstraints`, `strategy`,
  `priorityClassName`, `extraEnv`, `envFrom` and extra volumes.
- Standard `app.kubernetes.io` labels on object metadata. The selector stays the legacy
  `app`/`release` pair because it is immutable.

## 1.1.0

- **Liveness and readiness probes on `/info`**, and a `helm test` that calls it.
- **`enableServiceLinks: false`.** The injected `<SERVICE>_PORT` variables collide with the
  image's `KSQL_*` configuration and stop the server starting.
- The queries ConfigMap renders only in headless mode, and its content comes from
  `ksql.queries` instead of a file inside the chart.
- `ksql.headless` defaults to `false`, so the chart no longer ships a tutorial as its
  default workload.
- ksqlDB 7.9.0 -> 7.9.9.

## 1.0.0

First version in this repository's line. Upstream's numbering stopped when confluentinc
archived the repository, and `0.1.1` was a local bump made in k8s-manifests that was never
published anywhere.

- `Chart.yaml` is `apiVersion: v2`, with a declared `kubeVersion` floor of 1.22.
- Template unit tests covering what the chart rendered at that point.
