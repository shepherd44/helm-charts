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

## Install

```console
helm repo add shepherd44 https://shepherd44.github.io/helm-charts/docs
helm repo update shepherd44
helm install my-schema-registry shepherd44/cp-schema-registry \
  --version 0.1.1 \
  --set schema_registry.kafka.bootstrapServers="PLAINTEXT://my-kafka-headless:9092"
```

`schema_registry.kafka.bootstrapServers` is the one value with no usable default. Point
it at an existing Kafka; this chart does not bring one.

With a values file:

```console
helm install my-schema-registry shepherd44/cp-schema-registry \
  --version 0.1.1 -f my-values.yaml
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
| `schema_registry.imageTag` | Image tag | `7.5.3` |
| `schema_registry.imagePullPolicy` | Image pull policy | `IfNotPresent` |
| `schema_registry.imagePullSecrets` | Secrets for private registries | unset |
| `schema_registry.kafka.bootstrapServers` | Kafka bootstrap servers. **Required** | `""` |
| `schema_registry.configurationOverrides` | Schema Registry [configuration](https://docs.confluent.io/current/schema-registry/docs/config.html) overrides | `{}` |
| `schema_registry.customEnv` | Extra environment variables | `{}` |
| `schema_registry.servicePort` | Service port | `8081` |
| `schema_registry.heapOptions` | JVM heap options | `-Xms512M -Xmx512M` |
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
| `schema_registry.prometheus.jmx.enabled` | Run the JMX exporter as a sidecar | `true` |
| `schema_registry.prometheus.jmx.image` | Exporter image | `solsson/kafka-prometheus-jmx-exporter@sha256` |
| `schema_registry.prometheus.jmx.imageTag` | Exporter image tag (a digest) | see [values.yaml](values.yaml) |
| `schema_registry.prometheus.jmx.imagePullPolicy` | Exporter pull policy | `IfNotPresent` |
| `schema_registry.prometheus.jmx.port` | Exporter port | `5556` |
| `schema_registry.prometheus.jmx.resources` | Exporter requests and limits | `{}` |
| `schema_registry.prometheus.jmx.securityContext` | Exporter security context | UID/GID `10001`, non-root |
| `nameOverride` | Override the chart name | unset |
| `fullnameOverride` | Override the full release name | unset |
| `overrideGroupId` | Override the Schema Registry group id | unset |

`schema_registry.metrics.enabled` appears in `values.yaml` but no template reads it.
Setting it does nothing; the exporter is controlled by
`schema_registry.prometheus.jmx.enabled`.

The exporter sidecar exposes Prometheus metrics on `5556`, but this chart ships no
ServiceMonitor or PodMonitor — scraping has to be arranged separately.
