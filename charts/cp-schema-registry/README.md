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
| Chart | `0.3.0` |
| Schema Registry | `7.9.9` (Confluent Platform 7.9.x, Apache Kafka 3.9) |

Confluent supports each Community release for two years from its minor release date.
7.9.x runs out on 2027-02-19. The 7.5.x this chart used to ship ended 2025-08-25.

The JMX exporter sidecar is **off by default** — see [Metrics](#metrics).

## Install

```console
helm repo add shepherd44 https://shepherd44.github.io/helm-charts/docs
helm repo update shepherd44
helm install my-schema-registry shepherd44/cp-schema-registry \
  --version 0.3.0 \
  --set schema_registry.kafka.bootstrapServers="PLAINTEXT://my-kafka-headless:9092"
```

`schema_registry.kafka.bootstrapServers` is the one value with no usable default. Point
it at an existing Kafka; this chart does not bring one.

With a values file:

```console
helm install my-schema-registry shepherd44/cp-schema-registry \
  --version 0.3.0 -f my-values.yaml
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

`schema_registry.heapOptions` is passed as `SCHEMA_REGISTRY_HEAP_OPTS` when set, and is
empty by default so the JVM keeps its own container-aware sizing. Set it together with
`resources.limits.memory`, not on its own.

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
| `schema_registry.configurationOverrides` | Schema Registry [configuration](https://docs.confluent.io/current/schema-registry/docs/config.html) overrides | `{}` |
| `schema_registry.customEnv` | Extra environment variables | `{}` |
| `schema_registry.servicePort` | Service port | `8081` |
| `schema_registry.heapOptions` | `SCHEMA_REGISTRY_HEAP_OPTS`; omitted when empty | `""` |
| `schema_registry.livenessProbe` | Liveness probe, or `null` to omit | `httpGet /` |
| `schema_registry.readinessProbe` | Readiness probe, or `null` to omit | `httpGet /subjects` |
| `schema_registry.containerSecurityContext` | Security context for the Schema Registry container | drop ALL, no privilege escalation, RuntimeDefault |
| `schema_registry.podDisruptionBudget.enabled` | Create a PodDisruptionBudget | `false` |
| `schema_registry.podDisruptionBudget.minAvailable` | Minimum available pods | `1` |
| `schema_registry.podDisruptionBudget.maxUnavailable` | Maximum unavailable pods | `""` |
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
