# CP-Schema Registry Helm Chart

confluentinc에서 더이상 관리하지 않는 chart를 수정함
https://github.com/confluentinc/cp-helm-charts/tree/master/charts/cp-schema-registry

This chart bootstraps a deployment of a Confluent Schema Registry

## Prerequisites

* Kubernetes 1.9.2+
* Helm 3.0.2+
* A healthy and accessible Kafka Cluster

## Docker Image Source

* [DockerHub -> ConfluentInc](https://hub.docker.com/u/confluentinc/)

## Version

| | |
|---|---|
| Chart | `0.5.0` |
| Schema Registry | `7.9.9` (Confluent Platform 7.9.x, Apache Kafka 3.9) |

Confluent supports each Community release for two years from its minor release date.
7.9.x runs out on 2027-02-19. The 7.5.x this chart used to ship ended 2025-08-25.

- [CHANGELOG.md](CHANGELOG.md) — what changed in each chart version
- [docs/schema-registry-versions.md](docs/schema-registry-versions.md) — which Schema
  Registry version to pin, the support lifecycle, and what actually differs between them

The JMX exporter sidecar is **off by default** — see [Metrics](#metrics).

## Install

```console
helm repo add shepherd44 https://shepherd44.github.io/helm-charts/docs
helm repo update shepherd44
helm install my-schema-registry shepherd44/cp-schema-registry \
  --version 0.5.0 \
  --set schema_registry.kafka.bootstrapServers="PLAINTEXT://my-kafka-headless:9092"
```

`schema_registry.kafka.bootstrapServers` is the one value with no usable default. Point
it at an existing Kafka; this chart does not bring one.

With a values file:

```console
helm install my-schema-registry shepherd44/cp-schema-registry \
  --version 0.5.0 -f my-values.yaml
```

```yaml
# my-values.yaml
schema_registry:
  replicaCount: 2
  kafka:
    bootstrapServers: "PLAINTEXT://my-kafka-headless:9092"
  configurationOverrides:
    kafkastore.topic: _schemas
  resources:
    requests: { cpu: 200m, memory: 768Mi }
    limits:   { cpu: 500m, memory: 1Gi }
```

```console
helm upgrade my-schema-registry shepherd44/cp-schema-registry --version <new> -f my-values.yaml
helm uninstall my-schema-registry
```

The release has no persistent volumes — schemas live in the Kafka topic, so uninstalling
does not destroy them.

### What gets installed

A Deployment, a ClusterIP Service on port 8081, and a ConfigMap holding the Prometheus
JMX exporter config. `helm status <release>` lists them.

Reach it from inside the cluster at `http://<release>-cp-schema-registry:8081`, or
locally:

```console
kubectl port-forward svc/my-schema-registry-cp-schema-registry 8081:8081
curl localhost:8081/subjects
```

## Configuration

`schema_registry.configurationOverrides` becomes `SCHEMA_REGISTRY_*` environment, and
**takes precedence over the keys the chart sets itself** — `listeners`,
`kafkastore.bootstrap.servers`, `kafkastore.group.id`, `leader.eligibility`, `host.name`.
Before 0.5.0 overriding one of those emitted the variable twice; last-wins made it
mostly work, but it was not something to rely on.

```yaml
schema_registry:
  configurationOverrides:
    kafkastore.topic: _schemas
    schema.compatibility.level: full
    kafkastore.topic.replication.factor: "3"
```

`host.name` defaults to the pod IP via fieldRef. Setting it in
`configurationOverrides` replaces that entirely, which is what you want when instances
must advertise a routable name rather than a pod IP.

`schema_registry.leaderEligibility` controls `leader.eligibility` — whether an instance
may be elected the writer. Set it false only when another release is eligible; with no
eligible instance anywhere, schema registration fails.

The chart warns at install time when `configurationOverrides` contains a key that carries
`@Deprecated` upstream. All six still work in 8.3, so the warning is a nudge, not a
failure:

| Deprecated | Use instead |
|---|---|
| `master.eligibility` | `leader.eligibility` |
| `avro.compatibility.level` | `schema.compatibility.level` |
| `kafkastore.connection.url` | `kafkastore.bootstrap.servers` |
| `schema.registry.resource.extension.class` | `resource.extension.class` |
| `schema.registry.inter.instance.protocol` | `inter.instance.protocol` |
| `ssl.client.auth` | `ssl.client.authentication` |

Setting `master.eligibility` explicitly makes the chart stop emitting
`leader.eligibility`, so the two spellings never disagree.

[docs/schema-registry-versions.md](docs/schema-registry-versions.md) has the full field
inventory: what exists, what appeared in which version, and what the chart sets.

## Ingress

Off by default. The REST API is served on `servicePort` (8081).

```yaml
schema_registry:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: schema-registry.example.com
        paths:
          - path: /
            pathType: Prefix
```

`name` overrides the Ingress name, which is what you need to adopt an Ingress that
already exists under a different name — otherwise the chart creates a second one
alongside it and both point at the same Service.

```yaml
    name: idc-kafka-schema-registry
```

`annotations` passes through as-is, for the older `kubernetes.io/ingress.class` style or
anything controller-specific. `tls` takes the standard list of `{secretName, hosts}`.

Schema Registry has no authentication of its own here. An Ingress publishes a writable
API — anything that can reach it can register or delete schemas — so put it behind
something, or keep it cluster-internal.

## Health, scheduling, security

Probes are on by default. Liveness hits `/`, which only needs Jetty up; readiness hits
`/subjects`, which needs the Kafka store readable — that is the difference that matters,
since a Schema Registry that cannot reach Kafka should leave the Service, not restart.
Both are plain values: override them, or set either to `null` to omit it.

```yaml
schema_registry:
  readinessProbe:
    initialDelaySeconds: 30
  livenessProbe: null      # omit entirely
```

`schema_registry.containerSecurityContext` applies to the Schema Registry container:
no privilege escalation, all capabilities dropped, `RuntimeDefault` seccomp.
`readOnlyRootFilesystem` is deliberately absent — the Confluent image writes generated
config and logs inside the container.

`schema_registry.podDisruptionBudget` is off by default. At `replicaCount: 1` a budget
of `minAvailable: 1` does not protect anything, it just blocks node drains. Enable it
with two or more replicas.

`schema_registry.resources` is empty by default, and that is worth understanding before
leaving it that way. With no `limits.memory`, the container's cgroup reports no limit, so
the JVM sizes its heap from the **node**, not the container. Measured on a 257Gi node:

```
/sys/fs/cgroup/memory.max  ->  max
MaxRAMPercentage           =  25.0
MaxHeapSize                =  32178700288   (30GiB)
actual usage               =  288Mi
```

Nothing stops that heap from growing into the node. Setting `limits.memory` is what makes
the JVM container-aware; with a 1Gi limit the same JVM reports a 256Mi max heap.

`schema_registry.heapOptions` is passed as `SCHEMA_REGISTRY_HEAP_OPTS` when set and is
empty by default. Set it together with `limits.memory` rather than on its own — an `-Xmx`
above the limit gets the pod OOMKilled instead of throwing `OutOfMemoryError`.

The chart ships no default here on purpose: adding one would drop a memory limit onto
existing releases that currently run without one, turning a working deployment into an
OOMKill candidate at the next upgrade. Set it per deployment.

The Schema Registry container is rendered first and the pod carries
`kubectl.kubernetes.io/default-container`, so `kubectl logs`/`exec` without `-c` reach
the server rather than the metrics sidecar. Before 0.4.0 the sidecar was `containers[0]`,
which made its JVM startup output look like Schema Registry's.

Object metadata carries both the legacy `app`/`release`/`chart`/`heritage` labels and the
standard `app.kubernetes.io/*` set. The Deployment's `spec.selector` still uses only the
legacy pair, on purpose: a selector is immutable, so changing it would break
`helm upgrade` on every existing release.

## Metrics

`schema_registry.prometheus.jmx.enabled` runs a JMX exporter sidecar on port 5556. It is
**off by default**, for two reasons:

- it is a second JVM in every pod (~77Mi in the deployments this chart came from), and
- the chart creates no ServiceMonitor or PodMonitor. It only sets `prometheus.io/scrape`
  annotations, which a Prometheus Operator install ignores. Enabled but unscraped is the
  state this chart was in.

Turn it on only once something is configured to scrape port 5556:

```console
--set schema_registry.prometheus.jmx.enabled=true
```

The sidecar image is `shepherd9664/jmx-exporter`, built from
[shepherd44/containers](https://github.com/shepherd44/containers) on
[jmx_prometheus_standalone](https://github.com/prometheus/jmx_exporter) 1.6.0. There is
no maintained public image for this — `solsson/kafka-prometheus-jmx-exporter`, which
this chart used to run, was last pushed in 2020 on a JDK 8 base.

The old image was not merely stale, it was wrong on current nodes. Its command carried
`-XX:+UseCGroupMemoryLimitForHeap`, a JDK 8 flag that reads the **cgroup v1** path
`/sys/fs/cgroup/memory/memory.limit_in_bytes`. On a cgroup v2 node that file does not
exist, so the JVM logged

```
OpenJDK 64-Bit Server VM warning: Unable to open cgroup memory limit file /sys/fs/cgroup/memory/memory.limit_in_bytes
    Max. Heap Size (Estimated): 26.67G
```

and sized its heap from the host's memory instead of the container's. With no memory
limit on the sidecar, nothing else capped it either. The current image is JRE 21, which
reads cgroup v2 without help, and the flags are gone.

Its entrypoint is the jar, so the deployment passes only `args` (port, config file).
Pointing `schema_registry.prometheus.jmx.image` at a different image means matching that
contract; an image expecting `java -jar ...` to be spelled out in `command` will not
start.

The exporter config lives in a ConfigMap the chart renders, scraping three MBeans:
`jetty-metrics`, `jersey-metrics`, and `master-slave-role`. That last name is unchanged
through Confluent Platform 8.3, despite how it reads.

## Configuration

Every parameter lives under the `schema_registry` key — this chart nests them, unlike the
upstream confluent chart these docs came from.

```console
helm install my-schema-registry shepherd44/cp-schema-registry \
  --set schema_registry.replicaCount=2
```

> A default [values.yaml](values.yaml) is provided.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `schema_registry.replicaCount` | Number of Schema Registry servers | `1` |
| `schema_registry.image` | Image repository | `confluentinc/cp-schema-registry` |
| `schema_registry.imageTag` | Image tag | `7.9.9` |
| `schema_registry.imagePullPolicy` | Image pull policy | `IfNotPresent` |
| `schema_registry.imagePullSecrets` | Secrets for private registries | unset |
| `schema_registry.kafka.bootstrapServers` | Kafka bootstrap servers. **Required** | `""` |
| `schema_registry.configurationOverrides` | Schema Registry configuration; wins over chart-set keys | `{}` |
| `schema_registry.leaderEligibility` | `leader.eligibility` — may this instance become the writer | `true` |
| `schema_registry.customEnv` | Extra environment variables | `{}` |
| `schema_registry.servicePort` | Service port | `8081` |
| `schema_registry.heapOptions` | `SCHEMA_REGISTRY_HEAP_OPTS`; omitted when empty | `""` |
| `schema_registry.livenessProbe` | Liveness probe, or `null` to omit | `httpGet /` |
| `schema_registry.readinessProbe` | Readiness probe, or `null` to omit | `httpGet /subjects` |
| `schema_registry.containerSecurityContext` | Security context for the Schema Registry container | drop ALL, no privilege escalation, RuntimeDefault |
| `schema_registry.podDisruptionBudget.enabled` | Create a PodDisruptionBudget | `false` |
| `schema_registry.podDisruptionBudget.minAvailable` | Minimum available pods | `1` |
| `schema_registry.podDisruptionBudget.maxUnavailable` | Maximum unavailable pods | `""` |
| `schema_registry.ingress.enabled` | Create an Ingress | `false` |
| `schema_registry.ingress.name` | Ingress name; defaults to the chart fullname | `""` |
| `schema_registry.ingress.className` | `spec.ingressClassName` | `""` |
| `schema_registry.ingress.labels` | Extra labels on the Ingress | `{}` |
| `schema_registry.ingress.annotations` | Ingress annotations | `{}` |
| `schema_registry.ingress.hosts` | Hosts and paths | `[]` |
| `schema_registry.ingress.tls` | TLS blocks | `[]` |
| `schema_registry.schemaRegistryOpts` | Extra `SCHEMA_REGISTRY_OPTS` | unset |
| `schema_registry.resources` | Requests and limits | `{}` |
| `schema_registry.podAnnotations` | Annotations on the pod | `{}` |
| `schema_registry.nodeSelector` | Node selector | `{}` |
| `schema_registry.tolerations` | Tolerations | `[]` |
| `schema_registry.affinity` | Affinity | `{}` |
| `schema_registry.securityContext.runAsUser` | Container UID | `1000` |
| `schema_registry.securityContext.runAsGroup` | Container GID | `1000` |
| `schema_registry.securityContext.fsGroup` | Supplementary GID | `1000` |
| `schema_registry.securityContext.runAsNonRoot` | Refuse to run as root | `true` |
| `schema_registry.jmx.port` | JMX port | `5555` |
| `schema_registry.prometheus.jmx.enabled` | Run the JMX exporter as a sidecar | `false` |
| `schema_registry.prometheus.jmx.image` | Exporter image | `shepherd9664/jmx-exporter` |
| `schema_registry.prometheus.jmx.imageTag` | Exporter image tag | `1.6.0-latest` |
| `schema_registry.prometheus.jmx.imagePullPolicy` | Exporter pull policy | `IfNotPresent` |
| `schema_registry.prometheus.jmx.port` | Exporter port | `5556` |
| `schema_registry.prometheus.jmx.resources` | Exporter requests and limits | `{}` |
| `schema_registry.prometheus.jmx.securityContext` | Exporter security context | UID/GID `10001`, non-root |
| `nameOverride` | Override the chart name | unset |
| `fullnameOverride` | Override the full release name | unset |
| `overrideGroupId` | Override the Schema Registry group id | unset |

`schema_registry.metrics.enabled` used to sit in `values.yaml` doing nothing — no
template read it. Removed in 0.2.0; the sidecar is controlled by
`schema_registry.prometheus.jmx.enabled`.
