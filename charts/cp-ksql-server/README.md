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
  and `cp-schema-registry.url` below.

## Developing Environment

* [Pivotal Container Service (PKS)](https://pivotal.io/platform/pivotal-container-service)
* [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine/)

## Docker Image Source

* [DockerHub -> ConfluentInc](https://hub.docker.com/u/confluentinc/)

## Installing the Chart

### Install along with cp-helm-charts

```console
git clone https://github.com/confluentinc/cp-helm-charts.git
helm install cp-helm-charts
```

To install with a specific name, you can do:

```console
helm install --name my-confluent cp-helm-charts
```

### Install with a existing cp-kafka and cp-schema-registry release

```console
helm install --set cp-zookeeper.url="unhinged-robin-cp-zookeeper:2181",cp-schema-registry.url="http://lolling-chinchilla-cp-schema-registry:8081" cp-helm-charts/charts/cp-ksql-server
```

### Installed Components

You can use `helm status <release name>` to view all of the installed components.

For example:

```console
$ helm status excited-lynx
STATUS: DEPLOYED

RESOURCES:
==> v1/Service
NAME                         TYPE       CLUSTER-IP    EXTERNAL-IP  PORT(S)   AGE
excited-lynx-cp-ksql-server  ClusterIP  10.31.253.70  <none>       8088/TCP  10s

==> v1beta2/Deployment
NAME                         DESIRED  CURRENT  UP-TO-DATE  AVAILABLE  AGE
excited-lynx-cp-ksql-server  1        1        1           0          10s

==> v1/Pod(related)
NAME                                         READY  STATUS  RESTARTS  AGE
excited-lynx-cp-ksql-server-d4848ff94-x5fmn  2/2    Running   1         10s

==> v1/ConfigMap
NAME                                                DATA  AGE
excited-lynx-cp-ksql-server-jmx-configmap           1     10s
excited-lynx-cp-ksql-server-ksql-queries-configmap  1     10s


NOTES:
This chart installs Confluent KSQL Server.

https://docs.confluent.io/current/ksql/docs
```

There are
1. A [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) `excited-lynx-cp-ksql-server` which contains 1 KSQL Server instance [Pod](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/): `excited-lynx-cp-ksql-server-d4848ff94-x5fmn`.
1. A [Service](https://kubernetes.io/docs/concepts/services-networking/service/) `excited-lynx-cp-ksql-server` for clients to connect to KSQL Server.
1. A [ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) which contains configuration for Prometheus JMX Exporter.
1. A [ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) which contains SQL queries for the server to run in non-interactive mode.

## Configuration

You can specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart. For example,

```console
helm install --name my-ksql-server -f my-values.yaml ./cp-ksql-server
```

> **Tip**: A default [values.yaml](values.yaml) is provided

### KSQL Server Deployment

The configuration parameters in this section control the resources requested and utilized by the cp-ksql-server chart.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `replicaCount` | The number of KSQL Server instances. | `1` |

### Image

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `image` | Docker Image of Confluent KSQL Server. | `confluentinc/cp-ksql-server` |
| `imageTag` | Docker Image Tag of Confluent KSQL Server. | `7.9.9` |
| `imagePullPolicy` | Docker Image Tag of Confluent KSQL Server. | `IfNotPresent` |
| `imagePullSecrets` | Secrets to be used for private registries. | see [values.yaml](values.yaml) for details |

### KSQL Configuration
 Parameter | Description | Default |
| --------- | ----------- | ------- |
| `configurationOverrides` | KSQL [configuration](https://docs.confluent.io/current/ksql/docs/installation/server-config/config-reference.html) overrides in the dictionary format | `{}` |

### Mode and queries

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `ksql.headless` | Run non-interactively from a fixed queries file instead of serving the REST API. Off, which is the other way round from upstream — interactive is how ksqlDB is normally run, and upstream's headless default came with a tutorial as its workload. | `false` |
| `ksql.queries` | The SQL a headless server runs, mounted at `/etc/ksql/queries/queries.sql`. Required when `ksql.headless` is on; rendering fails without it, because a headless server with no queries starts, does nothing, and reports itself healthy. | `""` |
| `ksql.sinkReplicas` | Replication factor for sink topics. Interactive mode only. | `"3"` |
| `ksql.streamsReplicationFactor` | Replication factor for Kafka Streams internal topics. Interactive mode only. | `"3"` |
| `ksql.internalTopicReplicas` | Replication factor for ksqlDB's own internal topics. Interactive mode only. | `"3"` |

### Probes

Both probe `/info`, not `/healthcheck`: `/healthcheck` reports `commandRunner` unhealthy
on servers that are running their queries perfectly well, so a probe reading it would
take a working deployment out of service. Set either to `{}` to omit it.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `livenessProbe` | Restarts the container when the REST layer stops answering. | `GET /info`, 120s delay |
| `readinessProbe` | Holds the pod out of the Service until it answers. The delay and failure threshold allow for a command topic replay and a RocksDB state rebuild, which is minutes on a large state store. | `GET /info`, 30s delay, 12 failures |
| `enableServiceLinks` | Kubernetes injects a `<SERVICE>_PORT` variable per Service in the namespace, and the Confluent image reads `KSQL_*` as configuration — a Service named `ksql` next door stops the server from starting. | `false` |

### helm test

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `tests.enabled` | Render the `helm test` hook, one curl against `/info`. | `true` |
| `tests.image` | Image for the test pod. | `curlimages/curl:8.11.1` |
| `tests.securityContext` | Numeric `runAsUser` on purpose: the image's own user is the name `curl_user`, and a pod with `runAsNonRoot` and a non-numeric user is rejected before it starts. | see `values.yaml` |

### Port

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `servicePort` | The port on which the KSQL Server will be available and serving requests. | `8088` |

### KSQL JVM Heap Options

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `heapOptions` | The JVM Heap Options for KSQL | `"-Xms512M -Xmx512M"` |

### Resources

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `resources.requests.cpu` | The amount of CPU to request. | see [values.yaml](values.yaml) for details |
| `resources.requests.memory` | The amount of memory to request. | see [values.yaml](values.yaml) for details |
| `resources.requests.limit` | The upper limit CPU usage for a KSQL Server Pod. | see [values.yaml](values.yaml) for details |
| `resources.requests.limit` | The upper limit memory usage for a KSQL Server Pod. | see [values.yaml](values.yaml) for details |

### Annotations

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `podAnnotations` | Map of custom annotations to attach to the pod spec. | `{}` |

### JMX Configuration

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `jmx.port` | The jmx port which JMX style metrics are exposed. | `5555` |

### Prometheus JMX Exporter Configuration

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `prometheus.jmx.enabled` | Whether or not to install Prometheus JMX Exporter as a sidecar container and expose JMX metrics to Prometheus. | `true` |
| `prometheus.jmx.image` | Docker Image for Prometheus JMX Exporter container. | `solsson/kafka-prometheus-jmx-exporter@sha256` |
| `prometheus.jmx.imageTag` | Docker Image Tag for Prometheus JMX Exporter container. | `6f82e2b0464f50da8104acd7363fb9b995001ddff77d248379f8788e78946143` |
| `prometheus.jmx.imagePullPolicy` | Docker Image Pull Policy for Prometheus JMX Exporter container. | `IfNotPresent` |
| `prometheus.jmx.port` | JMX Exporter Port which exposes metrics in Prometheus format for scraping. | `5556` |
| `prometheus.jmx.resources` | JMX Exporter resources configuration. | see [values.yaml](values.yaml) for details |

### External Access

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `external.enabled` | whether or not to allow external access to KSQL Server | `false` |
| `external.type` | `Kubernetes Service Type` to expose KSQL Server to external | `LoadBalancer` |
| `external.port` | External service port to expose KSQL Server to external | `8082` |
| `external.annotations` | Map of annotations to attach to external KSQL Server service | `nil` |
| `external.externalTrafficPolicy` | Configures `.spec.externalTrafficPolicy` which controls if load balancing occurs across all nodes (value of `Cluster`) or only active nodes (value of `Local`)  | `Cluster` |
| `external.loadBalancerSourceRanges` | Configures `.spec.loadBalancerSourceRanges` which specifies the list of source IP ranges permitted access to the load balancer | `["0.0.0.0/0"]` |

### Deployment Topology

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `nodeSelector` | Dictionary containing key-value-pairs to match labels on nodes. When defined pods will only be scheduled on nodes, that have each of the indicated key-value pairs as labels. Further information can be found in the [Kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/) | `{}`
| `tolerations`| Array containing taint references. When defined, pods can run on nodes, which would otherwise deny scheduling. Further information can be found in the [Kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/) | `{}`

## Dependencies

### Schema Registry (optional)

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `cp-schema-registry.url` | Service name of Schema Registry (Not needed if this is installed along with cp-kafka chart). | `""` |
| `cp-schema-registry.port` | Port of Schema Registry Service | `8081` |
