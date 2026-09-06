# CP-Schema Registry Helm Chart

confluentinc에서 더이상 관리하지 않는 chart를 수정함
https://github.com/confluentinc/cp-helm-charts/tree/master/charts/cp-schema-registry

This chart bootstraps a deployment of a Confluent Schema Registry

## Prerequisites

* Kubernetes 1.22+ — declared as `kubeVersion` in `Chart.yaml`, so Helm refuses to
  install below it. 1.22 is well past upstream EOL (October 2022) and is supported here
  deliberately, for legacy clusters. Nothing the chart emits needs anything newer.
* Helm 3.14+ or Helm 4. CI renders the chart with both. On a 1.22-era cluster prefer
  Helm 3: Helm 4 is only supported against the Kubernetes versions it was built for.
* A healthy and accessible Kafka Cluster

## License

Apache-2.0, inherited from `confluentinc/cp-helm-charts`. Upstream shipped no per-chart
license file and the repository has since been deleted, so [LICENSE.md](LICENSE.md)
carries its `LICENSE` verbatim, recovered from a surviving fork. Local changes are in
[CHANGELOG.md](CHANGELOG.md).

## Docker Image Source

* [DockerHub -> ConfluentInc](https://hub.docker.com/u/confluentinc/)

## Version

| | |
|---|---|
| Chart | `1.6.0` |
| Schema Registry | `8.3.1` (Confluent Platform 8.3.x, Apache Kafka 4.3) |

Confluent supports each Community release for two years from its minor release date, and
designates no LTS line. 8.3.x runs out on 2027-06-17, which is the longest runway on
offer; the 7.9.x this chart shipped until 1.5.0 ends 2027-02-19.

8.3.1 talks to older brokers — verified against Kafka 3.5.1 here — so this is a tag bump,
not a broker upgrade. Pin `image.tag` if you want to stay on 7.9.x.

- [CHANGELOG.md](CHANGELOG.md) — what changed in each chart version
- [docs/schema-registry-versions.md](docs/schema-registry-versions.md) — which Schema
  Registry version to pin, the support lifecycle, and what actually differs between them

The JMX exporter sidecar is **off by default** — see [Metrics](#metrics).

## Kubernetes versions

The chart installs on **1.22 and up** — that is the `kubeVersion` in `Chart.yaml`, and
Helm refuses anything older. Everything the chart renders by default exists in 1.22.

Some values reach for fields that arrived later. They are all off by default, so a 1.22
cluster is never broken by leaving them alone; the table is for when you turn one on.

| Value | Needs | On 1.22, use instead |
|---|---|---|
| `topologySpreadConstraints` (the field itself) | 1.19 | works as-is |
| ├ `matchLabelKeys` inside it | 1.27 beta, 1.34 GA | spell the `labelSelector` out |
| ├ `minDomains` inside it | 1.27 beta, 1.30 GA | `affinity` with required pod anti-affinity |
| └ `nodeAffinityPolicy`, `nodeTaintsPolicy` | 1.26/1.27 beta, 1.30 GA | the defaults (`Honor`, `Ignore`) are what 1.22 does anyway |
| `metrics.mode: native` | 1.29 beta, 1.33 GA | `metrics.mode: sidecar`, the default |
| `networkPolicy` | 1.7 | works as-is — but do not put `endPort` in `extraRules`, that needs 1.25 |
| `ingress` | 1.19 (`networking.k8s.io/v1`) | works as-is |
| `podDisruptionBudget` | 1.21 (`policy/v1`) | works as-is |
| `httpRoute` | Gateway API CRDs: `v1beta1` needs 1.23, `v1` needs 1.25 | `ingress` |
| `metrics.serviceMonitor`, `podMonitor`, `prometheusRule` | not a Kubernetes version question | whatever the Prometheus Operator running there supports |

Two of those deserve a warning rather than a row.

**`metrics.mode: native` fails silently below 1.29.** There is no `restartPolicy` field
on an init container in 1.22; the API server drops what it does not know, the exporter
becomes an ordinary init container that never exits, and the pod hangs in `Init:0/1`
forever with nothing in the events to explain it. The chart cannot check this for you —
reading the cluster version at render time makes `helm template` and a server-side
GitOps render disagree — so it is a value you set deliberately.

**`kubeVersion` is checked by Helm, not by the cluster.** `helm template --kube-version`
and a cluster's real version both satisfy it, so a chart that renders is not proof that
every field in it is understood where it lands. That is what the table is for.

### Helm

Helm 3.14+ and Helm 4 both work; CI renders the chart with both. Helm's own support
policy covers the Kubernetes versions its binary was built against plus three behind, so
a 1.22 cluster sits outside what Helm 4 tests — on clusters that old, prefer Helm 3.

## Upgrading to 1.0.0

1.0.0 flattened the values. The rendered manifests did not change: 0.7.0 and 1.0.0 produce
byte-identical output for the same configuration.

A 0.7.0 values file keeps working as-is. Everything under `schema_registry` is mapped onto
the new keys, and the chart prints a warning at install time while any of it is in use.
The mapping wins key by key — what the old block sets overrides the same setting in the
new shape, what it leaves out falls through — so a file can be migrated a piece at a time.

Most keys just move up a level: `schema_registry.replicaCount` becomes `replicaCount`,
`schema_registry.resources` becomes `resources`, and so on. Eight changed shape as well:

| 0.7.0 | 1.0.0 |
|---|---|
| `schema_registry.image` (a string) | `image.repository` |
| `schema_registry.imageTag` | `image.tag` |
| `schema_registry.imagePullPolicy` | `image.pullPolicy` |
| `schema_registry.imagePullSecrets` | `image.pullSecrets` |
| `schema_registry.servicePort` | `service.port` |
| `schema_registry.securityContext` | `podSecurityContext` |
| `schema_registry.prometheus.jmx.*` | `metrics.*`, with `image`/`imageTag`/`imagePullPolicy` becoming `metrics.image.repository`/`.tag`/`.pullPolicy` |
| `schema_registry.tests.image` (a string) | `tests.image.repository`, likewise for the tag and pull policy |

Why bother: `--set` on a key a chart does not have is accepted silently, so
`--set image.tag=8.0.0` used to install the defaults and exit zero — it looked like it
worked. The nesting was also a standing argument about which convention each new key
should follow, and the list is about to grow.

## Install

```console
helm repo add shepherd44 https://shepherd44.github.io/helm-charts/docs
helm repo update shepherd44
helm install my-schema-registry shepherd44/cp-schema-registry \
  --version 1.5.0 \
  --set kafka.bootstrapServers="PLAINTEXT://my-kafka-headless:9092"
```

`kafka.bootstrapServers` is the one value with no usable default. Point
it at an existing Kafka; this chart does not bring one.

With a values file:

```console
helm install my-schema-registry shepherd44/cp-schema-registry \
  --version 1.5.0 -f my-values.yaml
```

```yaml
# my-values.yaml
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

`configurationOverrides` becomes `SCHEMA_REGISTRY_*` environment, and
**takes precedence over the keys the chart sets itself** — `listeners`,
`kafkastore.bootstrap.servers`, `kafkastore.group.id`, `leader.eligibility`, `host.name`.
Before 0.5.0 overriding one of those emitted the variable twice; last-wins made it
mostly work, but it was not something to rely on.

```yaml
configurationOverrides:
  kafkastore.topic: _schemas
  schema.compatibility.level: full
  kafkastore.topic.replication.factor: "3"
```

`host.name` defaults to the pod IP via fieldRef. Setting it in
`configurationOverrides` replaces that entirely, which is what you want when instances
must advertise a routable name rather than a pod IP.

`leaderEligibility` controls `leader.eligibility` — whether an instance
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

## Gateway API

`httpRoute.enabled` renders an `HTTPRoute` for clusters running a Gateway API controller.
It is **independent of `ingress`**, not an either/or switch: during a migration people
run both, and separate flags mean retiring one later is not a breaking change.

```yaml
httpRoute:
  enabled: true
  parentRefs:
    - name: my-gateway
      namespace: gateway-system
  hostnames:
    - schema-registry.example.com
```

With `rules` left empty the chart routes every path to its own Service, which is what
the Ingress does too. Set `rules` to take over completely — matches, filters, timeouts,
weighted backends; the chart then adds nothing of its own.

`parentRefs` is required. An HTTPRoute with no parent attaches to no Gateway and silently
routes nothing, so the chart fails rendering instead of shipping that.

Nothing is auto-detected: the chart renders the object on any cluster, and whether it
does anything depends on the CRDs and controller being there. `v1` needs Kubernetes 1.25
(`v1beta1`, 1.23) — see [Kubernetes versions](#kubernetes-versions).

The same warning as the Ingress applies, and harder: Schema Registry has no
authentication of its own, so a route that reaches it from outside the cluster exposes a
writable API.

## Health, scheduling, security

Probes are on by default. Liveness hits `/`, which only needs Jetty up; readiness hits
`/subjects`, which needs the Kafka store readable — that is the difference that matters,
since a Schema Registry that cannot reach Kafka should leave the Service, not restart.
Both are plain values: override them, or set either to `null` to omit it.

```yaml
readinessProbe:
  initialDelaySeconds: 30
livenessProbe: null      # omit entirely
```

The pods run as their own ServiceAccount, created by the chart, with
`automountServiceAccountToken: false`. Schema Registry talks to Kafka and never to the
Kubernetes API, so the token the `default` ServiceAccount would have mounted was a
credential nothing used. The ServiceAccount is also the only place cloud identity can be
attached without affecting every other workload in the namespace:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/schema-registry
```

Set `create: false` with an empty `name` to go back to the namespace default, or
`create: false` with a `name` to use a ServiceAccount managed elsewhere.

`containerSecurityContext` applies to the Schema Registry container:
no privilege escalation, all capabilities dropped, `RuntimeDefault` seccomp.
`readOnlyRootFilesystem` is deliberately absent — the Confluent image writes generated
config and logs inside the container.

`podDisruptionBudget` is off by default. At `replicaCount: 1` a budget
of `minAvailable: 1` does not protect anything, it just blocks node drains. Enable it
with two or more replicas.

`resources` is empty by default, and that is worth understanding before
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

`heapOptions` is passed as `SCHEMA_REGISTRY_HEAP_OPTS` when set and is
empty by default. Set it together with `limits.memory` rather than on its own — an `-Xmx`
above the limit gets the pod OOMKilled instead of throwing `OutOfMemoryError`.

The chart ships no default here on purpose: adding one would drop a memory limit onto
existing releases that currently run without one, turning a working deployment into an
OOMKill candidate at the next upgrade. Set it per deployment.

The Schema Registry container is rendered first and the pod carries
`kubectl.kubernetes.io/default-container`, so `kubectl logs`/`exec` without `-c` reach
the server rather than the metrics sidecar. Before 0.4.0 the sidecar was `containers[0]`,
which made its JVM startup output look like Schema Registry's.

There is no HPA and no KEDA `ScaledObject`, deliberately. Schema Registry elects a single
writer through the Kafka coordinator and forwards writes to it, so replicas do not
multiply write capacity; the reads it serves come from an in-memory cache backed by the
`_schemas` topic and are not CPU-bound. A CPU-metric HPA would mostly churn pods that
each replay the schemas topic on startup, and since readiness hits `/subjects`, the churn
shows up as pods that are slow to become ready rather than as throughput. Capacity here
is a small fixed replica count chosen for availability — which is what
`podDisruptionBudget` and pod anti-affinity are for.

Object metadata carries both the legacy `app`/`release`/`chart`/`heritage` labels and the
standard `app.kubernetes.io/*` set. The Deployment's `spec.selector` still uses only the
legacy pair, on purpose: a selector is immutable, so changing it would break
`helm upgrade` on every existing release.

## Network policy

`networkPolicy.enabled` writes an **ingress** policy: the REST port, plus the exporter
port when `metrics.enabled`, and nothing else. That is safe to turn on — it cannot break
the pod's own outbound traffic — and it closes every other port on the pod.

```yaml
networkPolicy:
  enabled: true
  ingress:
    from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: my-apps
```

Leaving `from` empty allows any pod in the cluster on those ports, which is still
narrower than having no policy.

Egress is a **separate switch**, because adding `Egress` to `policyTypes` denies every
outbound connection the rules do not name — including Kafka, which the chart cannot
locate for you: `kafka.bootstrapServers` is a hostname string, not a selector or a CIDR.

```yaml
networkPolicy:
  egress:
    enabled: true
    allowDNS: true          # 53/udp and 53/tcp; leave this on
    rules:
      - to:
          - podSelector:
              matchLabels:
                app.kubernetes.io/name: kafka
        ports:
          - port: 9092
            protocol: TCP
```

`allowDNS` is on by default and worth leaving there: the bootstrap servers are resolved
by name, so an egress policy without DNS takes the release down in a way that reads like
a Kafka outage.

## Spreading replicas

`affinity` and `topologySpreadConstraints` are both pass-throughs and both empty by
default. They are not alternatives — a pod spec can carry both.

```yaml
replicaCount: 3
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: cp-schema-registry
        release: my-release
```

Reach for spread constraints when the goal is "roughly balanced across zones", and for
required pod anti-affinity when the goal is "never two on one node". Worth pairing with
`podDisruptionBudget`: without a spread, three replicas can land on one node and the
budget protects nothing against a drain of it.

## Labels and annotations

`commonLabels` and `commonAnnotations` go on **every** object the chart renders —
Deployment, Service, ServiceAccount, ConfigMap, PodDisruptionBudget, Ingress, HTTPRoute,
the monitors, and the `helm test` pod:

```yaml
commonLabels:
  buzzni.com/team: de
commonAnnotations:
  buzzni.com/maintainer: james
```

Per-resource keys are merged on top and win where they overlap:

| object | labels | annotations |
|---|---|---|
| Deployment | `deployment.labels` | `deployment.annotations` |
| pods | `podLabels` | `podAnnotations` |
| Service | `service.labels` | `service.annotations` |
| ServiceAccount | `serviceAccount.labels` | `serviceAccount.annotations` |
| PodDisruptionBudget | `podDisruptionBudget.labels` | `podDisruptionBudget.annotations` |
| Ingress | `ingress.labels` | `ingress.annotations` |
| HTTPRoute | `httpRoute.labels` | `httpRoute.annotations` |
| ServiceMonitor / PodMonitor / PrometheusRule | `metrics.<kind>.labels` | `metrics.<kind>.annotations` |
| ConfigMap, test pod | common only | common only |

Precedence, lowest first: the chart's own labels, `commonLabels`, then the per-resource
key.

**None of this reaches the Deployment's `spec.selector`.** A selector is immutable, so it
keeps only the legacy `app`/`release` pair; a label added there would break
`helm upgrade` on every existing release. `podLabels` does reach the pod template, which
is fine — the selector is a subset of it.

## Service links are off

Kubernetes injects an environment variable set for every Service in the namespace when
`enableServiceLinks` is on, which is the cluster default:

```
SCHEMA_REGISTRY_SERVICE_HOST=10.100.149.104
SCHEMA_REGISTRY_PORT=tcp://10.100.149.104:8081
SCHEMA_REGISTRY_PORT_8081_TCP_ADDR=10.100.149.104
...
```

This image reads `SCHEMA_REGISTRY_*` as configuration. So a Service named
`schema-registry` puts `port=tcp://10.100.149.104:8081` in the properties file and the
container exits 1 a second after starting, with only this in the log:

```
PORT is deprecated. Please use SCHEMA_REGISTRY_LISTENERS instead.
```

The chart sets `enableServiceLinks: false` for that reason. It is not only this chart's
own Service that can do it — any sibling named `schema-registry*` in the namespace will
— and the injected set grows with the number of ports, so overriding the variables by
name does not hold. Schema Registry does not use them; brokers are found over DNS.

Set `enableServiceLinks: true` if something in your pod actually needs the variables.

## Credentials

`configurationOverrides` renders every value literally into the Deployment:

```yaml
- name: SCHEMA_REGISTRY_KAFKASTORE_SASL_JAAS_CONFIG
  value: "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"sr\" password=\"hunter2\";"
```

That is readable with `kubectl get deploy -o yaml`, printed by `helm get manifest`, and
committed verbatim into any GitOps repository that stores rendered manifests. Keep
secrets out of it and use `envFrom` instead — the keys must already be spelled the way
Schema Registry expects:

```yaml
envFrom:
  - secretRef:
      name: schema-registry-kafka-credentials   # SCHEMA_REGISTRY_KAFKASTORE_SASL_JAAS_CONFIG, ...
```

A JKS truststore or keystore is mounted the same way. The server container mounts
nothing by default:

```yaml
extraVolumes:
  - name: kafka-truststore
    secret:
      secretName: kafka-truststore
extraVolumeMounts:
  - name: kafka-truststore
    mountPath: /etc/schema-registry/secrets
    readOnly: true
configurationOverrides:
  kafkastore.ssl.truststore.location: /etc/schema-registry/secrets/truststore.jks
  # the password comes from envFrom, not from here
```

## Verify a release

The chart ships a `helm test` hook — a pod that curls `/subjects` on the release's own
Service:

```console
helm test my-schema-registry
```

`/subjects` needs the Kafka store to be readable, so it fails when the registry is up but
its backing topic is not, which is the failure worth catching. It proves three things
`helm install` alone does not: the Service selector matches the pods, the port name
resolves, and the Kafka store is reachable.

The hook runs only on `helm test`, never on install or upgrade. Set
`tests.enabled=false` to leave it out of the release entirely, or point
`tests.image.repository` at a mirror if `curlimages/curl` is not pullable.

CI runs it automatically: `ct install` installs each `ci/*-values.yaml` on a KinD cluster
and then runs `helm test` against it.

## Metrics

`metrics.enabled` runs a JMX exporter sidecar on port 5556. It is **off by default**: it
is a second JVM in every pod (~77Mi in the deployments this chart came from), and it is
worth nothing until something scrapes it.

```console
--set metrics.enabled=true
```

### How it runs in the pod

`metrics.mode` decides whether the exporter is an ordinary container or a Kubernetes
sidecar container:

- `sidecar` (default) — a normal container. No ordering guarantee: it can start before
  JMX is listening and log connection errors on every pod start, and on shutdown it can
  outlive or predecease the thing it scrapes.
- `native` — an init container with `restartPolicy: Always`, started before the main
  container and stopped after it. **Needs Kubernetes 1.29 or newer.** Below that the
  field is dropped and the pod never finishes starting; see
  [Kubernetes versions](#kubernetes-versions).

### Getting it scraped

Two mechanisms, and which one works depends on how Prometheus was installed.

**Prometheus Operator / kube-prometheus-stack** reads `ServiceMonitor` and `PodMonitor`
custom resources and ignores scrape annotations entirely. This is the common case:

```yaml
metrics:
  enabled: true
  scrapeAnnotations: false        # nothing reads them here
  serviceMonitor:
    enabled: true
    labels:
      release: kube-prometheus-stack   # see below
```

`labels` almost always has to carry whatever the `Prometheus` resource selects on. With
kube-prometheus-stack that is `release: <the stack's release name>`; check with

```console
kubectl get prometheus -A -o jsonpath='{.items[*].spec.serviceMonitorSelector}'
```

Get it wrong and the ServiceMonitor is created, looks right, and is never scraped —
which is the failure this chart's users hit before it existed.

`podMonitor` is the same thing against the pods rather than the Service. Prefer
`serviceMonitor`: it follows the Service's endpoints, so replica changes need no
attention. Enabling both is an error — one exporter, scraped twice, under two job names.

A monitor without `metrics.enabled` is also an error rather than a no-op: there would be
nothing listening on the port it points at.

**A hand-configured Prometheus** using `kubernetes_sd_configs` and relabeling reads the
`prometheus.io/scrape` and `prometheus.io/port` annotations on the pod. Those are still
emitted, controlled by `metrics.scrapeAnnotations` (default `true` — turning it off is
what keeps an Operator setup from also discovering the pod by annotation).

### Alerts

`metrics.prometheusRule` creates a `PrometheusRule`, with the rules given in
`metrics.prometheusRule.rules` in one group named after the release. The chart ships no
default alerts — what is worth alerting on depends on the deployment — so enabling it
without rules is an error rather than an empty rule group:

```yaml
metrics:
  prometheusRule:
    enabled: true
    labels:
      release: kube-prometheus-stack
    rules:
      - alert: SchemaRegistryDown
        expr: up{job="my-release-cp-schema-registry"} == 0
        for: 5m
        labels:
          severity: critical
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
Pointing `metrics.image.repository` at a different image means matching that
contract; an image expecting `java -jar ...` to be spelled out in `command` will not
start.

The exporter config lives in a ConfigMap the chart renders, scraping three MBeans:
`jetty-metrics`, `jersey-metrics`, and `master-slave-role`. That last name is unchanged
through Confluent Platform 8.3, despite how it reads.

## Configuration

Parameters are top-level. Before 1.0.0 they all sat under a `schema_registry` key; that
block still works and is still mapped, but it is deprecated — see
[Upgrading to 1.0.0](#upgrading-to-100).

```console
helm install my-schema-registry shepherd44/cp-schema-registry \
  --set replicaCount=2
```

> A default [values.yaml](values.yaml) is provided.

Values are validated against [values.schema.json](values.schema.json) on install,
upgrade, lint and template. It is permissive about keys the chart does not know — people
carry extra values through wrappers — and strict inside the maps the chart owns, so
`--set image.repo=x` fails with the offending path instead of installing the defaults.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `replicaCount` | Number of Schema Registry servers | `1` |
| `image.repository` | Image repository | `confluentinc/cp-schema-registry` |
| `image.tag` | Image tag | `8.3.1` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.pullSecrets` | Secrets for private registries | unset |
| `kafka.bootstrapServers` | Kafka bootstrap servers. **Required** | `""` |
| `configurationOverrides` | Schema Registry configuration; wins over chart-set keys | `{}` |
| `leaderEligibility` | `leader.eligibility` — may this instance become the writer | `true` |
| `customEnv` | Extra environment variables | `{}` |
| `service.port` | Service port | `8081` |
| `heapOptions` | `SCHEMA_REGISTRY_HEAP_OPTS`; omitted when empty | `""` |
| `livenessProbe` | Liveness probe, or `null` to omit | `httpGet /` |
| `readinessProbe` | Readiness probe, or `null` to omit | `httpGet /subjects` |
| `containerSecurityContext` | Security context for the Schema Registry container | drop ALL, no privilege escalation, RuntimeDefault |
| `podDisruptionBudget.enabled` | Create a PodDisruptionBudget | `false` |
| `podDisruptionBudget.minAvailable` | Minimum available pods | `1` |
| `podDisruptionBudget.maxUnavailable` | Maximum unavailable pods | `""` |
| `networkPolicy.enabled` | Create a NetworkPolicy (ingress rules) | `false` |
| `networkPolicy.ingress.from` | Allowed sources; empty means any pod in the cluster | `[]` |
| `networkPolicy.ingress.extraRules` | Extra ingress rules, passed through | `[]` |
| `networkPolicy.egress.enabled` | Also restrict outbound traffic | `false` |
| `networkPolicy.egress.allowDNS` | Allow 53/udp and 53/tcp | `true` |
| `networkPolicy.egress.rules` | Egress rules, passed through — Kafka goes here | `[]` |
| `ingress.enabled` | Create an Ingress | `false` |
| `ingress.name` | Ingress name; defaults to the chart fullname | `""` |
| `ingress.className` | `spec.ingressClassName` | `""` |
| `ingress.labels` | Extra labels on the Ingress | `{}` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Hosts and paths | `[]` |
| `ingress.tls` | TLS blocks | `[]` |
| `httpRoute.enabled` | Create an HTTPRoute (Gateway API) | `false` |
| `httpRoute.name` | Override the object name | fullname |
| `httpRoute.labels` | Extra labels | `{}` |
| `httpRoute.annotations` | Extra annotations | `{}` |
| `httpRoute.parentRefs` | Gateways to attach to; required when enabled | `[]` |
| `httpRoute.hostnames` | Hostnames to match | `[]` |
| `httpRoute.rules` | Full rule list; empty means route `/` to the Service | `[]` |
| `schemaRegistryOpts` | Extra `SCHEMA_REGISTRY_OPTS` | unset |
| `resources` | Requests and limits | `{}` |
| `commonLabels` | Labels added to every object | `{}` |
| `commonAnnotations` | Annotations added to every object | `{}` |
| `deployment.labels` | Extra labels on the Deployment | `{}` |
| `deployment.annotations` | Extra annotations on the Deployment | `{}` |
| `podLabels` | Extra labels on the pods | `{}` |
| `podAnnotations` | Annotations on the pod | `{}` |
| `service.labels` | Extra labels on the Service | `{}` |
| `service.annotations` | Extra annotations on the Service | `{}` |
| `podDisruptionBudget.labels` | Extra labels on the PDB | `{}` |
| `podDisruptionBudget.annotations` | Extra annotations on the PDB | `{}` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity | `{}` |
| `topologySpreadConstraints` | Spread replicas across zones or nodes | `[]` |
| `podSecurityContext.runAsUser` | Container UID | `1000` |
| `podSecurityContext.runAsGroup` | Container GID | `1000` |
| `podSecurityContext.fsGroup` | Supplementary GID | `1000` |
| `podSecurityContext.runAsNonRoot` | Refuse to run as root | `true` |
| `jmx.port` | JMX port | `5555` |
| `serviceAccount.create` | Create a ServiceAccount for the pods | `true` |
| `serviceAccount.name` | Name of the ServiceAccount | fullname when created, `default` otherwise |
| `serviceAccount.annotations` | ServiceAccount annotations (IRSA, Workload Identity) | `{}` |
| `serviceAccount.labels` | ServiceAccount labels | `{}` |
| `serviceAccount.automountServiceAccountToken` | Mount the API token into the pods | `false` |
| `envFrom` | Env from existing Secrets/ConfigMaps — use this for credentials | `[]` |
| `extraVolumes` | Extra pod volumes | `[]` |
| `extraVolumeMounts` | Extra mounts on the server container | `[]` |
| `initContainers` | Extra init containers | `[]` |
| `extraContainers` | Extra sidecar containers | `[]` |
| `priorityClassName` | Pod priority class | `""` |
| `enableServiceLinks` | Inject Kubernetes service-link env vars into the pods | `false` |
| `terminationGracePeriodSeconds` | Shutdown grace period | unset (Kubernetes default 30s) |
| `tests.enabled` | Render the `helm test` hook | `true` |
| `tests.image.repository` | Test hook image (needs curl) | `curlimages/curl` |
| `tests.image.tag` | Test hook image tag | `8.11.1` |
| `tests.image.pullPolicy` | Test hook pull policy | `IfNotPresent` |
| `tests.image.pullSecrets` | Test hook pull secrets | `[]` |
| `tests.resources` | Test hook requests and limits | `{}` |
| `tests.securityContext` | Test hook security context | numeric UID/GID `100`, non-root |
| `metrics.enabled` | Run the JMX exporter as a sidecar | `false` |
| `metrics.mode` | `sidecar`, or `native` for a Kubernetes sidecar container (needs k8s 1.29+) | `sidecar` |
| `metrics.image.repository` | Exporter image | `shepherd9664/jmx-exporter` |
| `metrics.image.tag` | Exporter image tag | `1.6.0-latest` |
| `metrics.image.pullPolicy` | Exporter pull policy | `IfNotPresent` |
| `metrics.port` | Exporter port | `5556` |
| `metrics.resources` | Exporter requests and limits | `{}` |
| `metrics.securityContext` | Exporter security context | UID/GID `10001`, non-root |
| `metrics.scrapeAnnotations` | Emit `prometheus.io/scrape` on the pod | `true` |
| `metrics.serviceMonitor.enabled` | Create a ServiceMonitor | `false` |
| `metrics.serviceMonitor.namespace` | Namespace for it | release namespace |
| `metrics.serviceMonitor.labels` | Extra labels — usually the Prometheus selector | `{}` |
| `metrics.serviceMonitor.annotations` | Extra annotations | `{}` |
| `metrics.serviceMonitor.jobLabel` | Label to take the job name from | unset |
| `metrics.serviceMonitor.interval` | Scrape interval | Prometheus default |
| `metrics.serviceMonitor.scrapeTimeout` | Scrape timeout | Prometheus default |
| `metrics.serviceMonitor.path` | Metrics path | `/metrics` |
| `metrics.serviceMonitor.scheme` | `http` or `https` | `http` |
| `metrics.serviceMonitor.honorLabels` | Keep target labels on collision | `false` |
| `metrics.serviceMonitor.selector` | Extra matchLabels on the Service | `{}` |
| `metrics.serviceMonitor.relabelings` | Target relabelings | `[]` |
| `metrics.serviceMonitor.metricRelabelings` | Metric relabelings | `[]` |
| `metrics.podMonitor.*` | Same keys, scraping pods instead of the Service | off |
| `metrics.prometheusRule.enabled` | Create a PrometheusRule | `false` |
| `metrics.prometheusRule.namespace` | Namespace for it | release namespace |
| `metrics.prometheusRule.labels` | Extra labels — usually the Prometheus selector | `{}` |
| `metrics.prometheusRule.annotations` | Extra annotations | `{}` |
| `metrics.prometheusRule.rules` | Alerting/recording rules; required when enabled | `[]` |
| `nameOverride` | Override the chart name | unset |
| `fullnameOverride` | Override the full release name | unset |
| `overrideGroupId` | Override the Schema Registry group id | unset |
| `schema_registry` | Deprecated pre-1.0.0 layout, mapped onto the keys above | `{}` |

`metrics.enabled` used to sit in `values.yaml` doing nothing — no
template read it. Removed in 0.2.0; the sidecar is controlled by
`metrics.enabled`.
