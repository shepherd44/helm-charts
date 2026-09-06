# KSQL Server Helm Chart

This chart bootstraps a deployment of a Confluent ksqlDB Server.

This is an example deployment which runs KSQL Server in non-interactive
mode.
The included queries file `queries.sql` is a stub provided to illustrate one possible approach to mounting queries in the server container via ConfigMap.

## Fork notice

Forked from `confluentinc/cp-helm-charts`, `charts/cp-ksql-server`. Upstream archived
that repository and the chart has had no maintainer there for years — the tables below
still describe a 6.1.0 image and a Helm 2 install command, which is the state it was
abandoned in.

What this repository vendored is not upstream itself. It is the copy that the live
`cp-ksqldb-server` release runs from in the `de-data-kafka` and `de-data-kafka-dev`
namespaces, already patched once — Confluent image bumped to 7.9.0, chart renumbered to
0.1.1. Both namespaces held byte-identical copies, so the base is unambiguous. Taking the
running chart rather than an archived upstream is the point: it is what a future diff of
the deployed configuration has to be taken against.

Version numbers diverge from upstream here. Releases from this repository take the next
number in this chart's own line and are never republished under an upstream number.

## License

Apache-2.0, inherited from `confluentinc/cp-helm-charts`. Upstream shipped no per-chart
license file and the repository has since been deleted, so [LICENSE.md](LICENSE.md)
carries its `LICENSE` verbatim, recovered from a surviving fork.

## Prerequisites

* Kubernetes 1.22+ — declared as `kubeVersion` in `Chart.yaml`, so Helm refuses to
  install below it. 1.22 is well past upstream EOL (October 2022) and is supported here
  deliberately, for legacy clusters. Nothing the chart emits needs anything newer.
* Helm 3.14+ or Helm 4. CI renders the chart with both. On a 1.22-era cluster prefer
  Helm 3: Helm 4 is only supported against the Kubernetes versions it was built for.
* A healthy and accessible Kafka cluster, and a Schema Registry if any query uses Avro,
  Protobuf or JSON Schema. Neither has a usable default — see `kafka.bootstrapServers`
  and `schemaRegistry.url` below.

## Docker image source

* [DockerHub -> ConfluentInc](https://hub.docker.com/u/confluentinc/)

## Installing the chart

```console
helm install my-ksql oci://ghcr.io/shepherd44/charts/cp-ksql-server --version <version> \
  --set kafka.bootstrapServers=PLAINTEXT://kafka-bootstrap:9092 \
  --set schemaRegistry.url=http://cp-schema-registry:8081
```

Neither endpoint has a usable default. Left empty, the chart guesses at sibling releases
of the cp-kafka and cp-schema-registry charts from the archived `cp-helm-charts`
repository — names that will not exist in any cluster built this decade.

The chart creates a Deployment, a Service, a ServiceAccount, a ConfigMap holding the JMX
exporter rules, and — in headless mode only — a second ConfigMap holding the queries.
`helm test` adds one short-lived pod that curls `/info`.

## Configuration

Each parameter can be set with `--set key=value`, or by passing a values file with `-f`.
`helm show values oci://ghcr.io/shepherd44/charts/cp-ksql-server --version <version>`
prints the current defaults with their comments, which are the authoritative version of
the tables below.

### Values layout changed in 1.2.0

The chart used the layout it was forked with, which did not match any other chart here.
The old names still work — they are mapped onto the new keys and win where both are set,
and `NOTES.txt` warns when a release is still using them — but new values files should
use the new ones.

| Was | Is |
| --- | -- |
| `imageTag`, `imagePullPolicy`, `imagePullSecrets` | `image.tag`, `image.pullPolicy`, `image.pullSecrets` |
| `servicePort` | `service.port` |
| `prometheus.jmx.*` | `metrics.*`, with `image`/`imageTag` folded into `metrics.image.*` |
| `cp-schema-registry.url` | `schemaRegistry.url` |

`image` is the one exception and fails the render instead of being mapped. Old and new
share that key, so a bare `image: confluentinc/cp-ksqldb-server` does not sit beside the
new map — Helm replaces the map with the string, taking the chart's own `tag` and
`pullPolicy` defaults with it, and there is no shape left to merge back from. Set
`image.repository` and `image.tag`.

### Deployment

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `replicaCount` | Number of ksqlDB server instances. | `1` |
| `serviceId` | ksqlDB service id. It names every internal topic the server owns — `_confluent-ksql-<serviceId>_command_topic` and the state store topics behind each query — so **changing it on a running deployment orphans all of them** and starts again from an empty state. | `cp-ksql-server` |
| `nameOverride`, `fullnameOverride` | Override the generated names. | `""` |
| `strategy` | Deployment update strategy. Unset means the Kubernetes default rolling update. | `{}` |
| `priorityClassName` | Pod priority class. | `""` |
| `terminationGracePeriodSeconds` | Unset means the Kubernetes default of 30s. | `null` |

### Image

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `image.repository` | ksqlDB server image. | `confluentinc/cp-ksqldb-server` |
| `image.tag` | Image tag. | `7.9.9` |
| `image.pullPolicy` | | `IfNotPresent` |
| `image.pullSecrets` | Secrets for a private registry. Must already exist in the namespace. | `[]` |

### Kafka, Schema Registry and ksqlDB configuration

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `kafka.bootstrapServers` | Kafka bootstrap servers. No usable default. | `""` |
| `schemaRegistry.url` | Schema Registry URL, needed by any query using Avro, Protobuf or JSON Schema. | `""` |
| `schemaRegistry.nameOverride` | Only used to guess a sibling release's Service name when `url` is empty. | `""` |
| `configurationOverrides` | ksqlDB [configuration](https://docs.confluent.io/current/ksql/docs/installation/server-config/config-reference.html) as a map. Each key becomes an environment variable: dots to underscores, upper-cased, `KSQL_` prefixed. **Rendered literally into the Deployment**, so anything sensitive belongs in `envFrom` instead. | `{}` |
| `extraEnv` | Additional environment variables, rendered as written. | `[]` |
| `envFrom` | Env from existing Secrets or ConfigMaps. Keys must already be spelled the way the image expects, e.g. `KSQL_KSQL_STREAMS_SASL_JAAS_CONFIG`. | `[]` |
| `extraVolumes`, `extraVolumeMounts` | Extra volumes on the server container — a JKS truststore comes in this way. | `[]` |

### Mode and queries

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `ksql.headless` | Run non-interactively from a fixed queries file instead of serving the REST API. Off, which is the other way round from upstream — interactive is how ksqlDB is normally run, and upstream's headless default came with a tutorial as its workload. | `false` |
| `ksql.queries` | The SQL a headless server runs, mounted at `/etc/ksql/queries/queries.sql`. Required when `ksql.headless` is on; rendering fails without it, because a headless server with no queries starts, does nothing, and reports itself healthy. | `""` |
| `ksql.sinkReplicas` | Replication factor for sink topics. Interactive mode only. | `"3"` |
| `ksql.streamsReplicationFactor` | Replication factor for Kafka Streams internal topics. Interactive mode only. | `"3"` |
| `ksql.internalTopicReplicas` | Replication factor for ksqlDB's own internal topics. Interactive mode only. | `"3"` |

### Probes and service links

Both probes call `/info`, not `/healthcheck`: `/healthcheck` reports `commandRunner`
unhealthy on servers that are running their queries perfectly well — every ksqlDB pod in
both k8s-idc namespaces answers that way — so a probe reading it would take a working
deployment out of service. Set either probe to `{}` to omit it.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `livenessProbe` | Restarts the container when the REST layer stops answering. | `GET /info`, 120s delay |
| `readinessProbe` | Holds the pod out of the Service until it answers. The delay and failure threshold allow for a command topic replay and a RocksDB state rebuild, which is minutes on a large state store. | `GET /info`, 30s delay, 12 failures |
| `enableServiceLinks` | Kubernetes injects a `<SERVICE>_PORT` variable per Service in the namespace, and the image reads `KSQL_*` as configuration — a Service named `ksql` next door stops the server from starting. | `false` |

### Resources

`heapOptions` sizes the heap only. A server with persistent queries holds most of its
memory off-heap in RocksDB, and that grows with the key space of the tables it maintains:
the k8s-idc production servers sit around 2.2Gi of working set against a 512M heap and
were still climbing after ten months. Size `resources.limits.memory` from measurement.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `heapOptions` | JVM heap options. | `-Xms512M -Xmx512M` |
| `resources` | Requests and limits for the server container. | `{}` |
| `podSecurityContext` | Pod-level security context. The image's own user is `appuser`, uid 1000. | uid/gid 1000, `runAsNonRoot` |
| `containerSecurityContext` | Container-level context. `readOnlyRootFilesystem` is deliberately unset: the image writes its generated configuration under the container filesystem, and Kafka Streams keeps RocksDB state under `/tmp`. | drops all capabilities, `RuntimeDefault` seccomp |

### Service and networking

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `service.port` | Port the REST API is served and exposed on. | `8088` |
| `service.labels`, `service.annotations` | Extra metadata on the Service. | `{}` |
| `external.enabled` | Also create a LoadBalancer Service. | `false` |
| `external.type`, `external.port`, `external.externalTrafficPolicy` | | `LoadBalancer`, `8088`, `Cluster` |
| `external.loadBalancerSourceRanges` | Source CIDRs permitted through the load balancer. | `[]` |
| `external.labels`, `external.annotations` | Extra metadata on the external Service. | `{}` |

### Metadata, scheduling and availability

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `commonLabels`, `commonAnnotations` | Added to every object the chart creates. Per-resource blocks are merged over these and win. | `{}` |
| `podLabels`, `podAnnotations` | Added to the pod only. | `{}` |
| `serviceAccount.create` | Create a ServiceAccount named after the release. | `true` |
| `serviceAccount.name` | Use an existing one. With `create: false` and no name, the pod falls back to `default`. | `""` |
| `serviceAccount.automountServiceAccountToken` | ksqlDB talks to Kafka, not to the API server. | `false` |
| `podDisruptionBudget.enabled` | Off by default: with `replicaCount: 1` a budget of `minAvailable: 1` blocks node drains outright. Enable it alongside `replicaCount >= 2`. | `false` |
| `podDisruptionBudget.minAvailable`, `.maxUnavailable` | | `1`, `""` |
| `nodeSelector`, `tolerations`, `affinity` | Standard scheduling controls. | `{}`, `[]`, `{}` |
| `topologySpreadConstraints` | Spread replicas across nodes or zones. Available since Kubernetes 1.19, within this chart's 1.22 floor. | `[]` |

The object metadata carries the standard `app.kubernetes.io/*` labels. The Deployment's
`spec.selector` deliberately does not: it stays the legacy `app`/`release` pair, because
a selector is immutable and changing it would make `helm upgrade` fail on every existing
release with "field is immutable".

### Metrics

The sidecar is on by default, unlike `cp-schema-registry`, because both live deployments
run it and turning it off here would silently drop their metrics on the first upgrade.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `metrics.enabled` | Run the Prometheus JMX exporter as a sidecar and add the `prometheus.io/*` scrape annotations. | `true` |
| `metrics.port` | Port the exporter serves on, named `metrics` on the Service. | `5556` |
| `metrics.image.repository`, `.tag`, `.pullPolicy` | Exporter image. Pinned by digest, which is why the repository carries the `@sha256` suffix and the tag holds the digest. | see `values.yaml` |
| `metrics.resources`, `metrics.securityContext` | For the exporter container. | `{}` |
| `jmx.port` | Port the JVM exposes JMX on, for the exporter to read. | `5555` |

### helm test

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `tests.enabled` | Render the `helm test` hook, one curl against `/info`. | `true` |
| `tests.image` | Image for the test pod. | `curlimages/curl:8.11.1` |
| `tests.securityContext` | Numeric `runAsUser` on purpose: the image's own user is the name `curl_user`, and a pod with `runAsNonRoot` and a non-numeric user is rejected before it starts. | see `values.yaml` |
| `tests.resources` | | see `values.yaml` |
