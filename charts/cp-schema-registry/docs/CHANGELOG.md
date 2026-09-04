# Chart changelog

Chart versions of `cp-schema-registry`. The chart's own line, not Confluent's — see
[schema-registry-versions.md](schema-registry-versions.md) for the application side.

Each release is tagged in git as `cp-schema-registry-<version>`.

## 0.4.0

- **Ingress** (`schema_registry.ingress`), off by default. `name` overrides the Ingress
  name so an Ingress that already exists under a different name can be adopted rather
  than duplicated. `className`, `labels`, `annotations`, `hosts`, `tls` supported.
- **Container order.** The Schema Registry container renders first and the pod carries
  `kubectl.kubernetes.io/default-container`. Previously the metrics sidecar was
  `containers[0]`, so `kubectl logs`/`exec` without `-c` reached the exporter — which is
  how a JVM warning from the sidecar came to look like Schema Registry's.

## 0.3.0

- **Probes.** There were none at all before, so an instance that lost Kafka kept taking
  traffic. Liveness on `/` (Jetty up), readiness on `/subjects` (Kafka store readable).
  Both are plain values; set either to `null` to omit it. Verified as HTTP 200 against a
  live 7.5.7 instance before being made defaults.
- **`heapOptions` wired** to `SCHEMA_REGISTRY_HEAP_OPTS`, and its default changed to `""`.
  It had defaulted to `-Xms512M -Xmx512M` while the template ignored it, so connecting the
  two on the old default would have silently resized the heap of running releases.
- **`containerSecurityContext`** for the Schema Registry container: drop ALL capabilities,
  no privilege escalation, `RuntimeDefault` seccomp. Not `readOnlyRootFilesystem` — the
  Confluent image writes generated config and logs inside the container.
- **Optional PodDisruptionBudget**, disabled by default. At `replicaCount: 1` a
  `minAvailable: 1` budget protects nothing and blocks node drains.
- **`app.kubernetes.io/*` labels** on object metadata. `spec.selector` deliberately keeps
  only the legacy `app`/`release` pair: a Deployment selector is immutable, so changing it
  would fail `helm upgrade` on every existing release.

## 0.2.0

- **Schema Registry 7.5.3 → 7.9.9.** 7.5.x reached Confluent Community end of support on
  2025-08-25.
- **JMX exporter sidecar is opt-in** (`enabled: false`). It had been on by default while
  nothing scraped it — the chart creates no ServiceMonitor or PodMonitor and only sets
  `prometheus.io/scrape` annotations, which a Prometheus Operator install ignores.
- **Sidecar image** `solsson/kafka-prometheus-jmx-exporter` (last pushed 2020-04-23) →
  `shepherd9664/jmx-exporter` on `jmx_prometheus_standalone` 1.6.0. No maintained public
  image exists for this; prometheus/jmx_exporter ships jars only.
- **Sidecar command → args.** 1.x renamed the jar and the new image's entrypoint is the
  jar itself. This also dropped `-XX:+UnlockExperimentalVMOptions`,
  `-XX:+UseCGroupMemoryLimitForHeap` and `-XX:MaxRAMFraction=1` — JDK 8 flags that JDK 11
  removed, and that produced a cgroup warning on cgroup v2 nodes.
- Chart `apiVersion` v1 → v2.
- Exporter config uses `includeObjectNames` rather than the deprecated
  `whitelistObjectNames`.
- **`metrics.enabled` removed.** No template ever read it, so it read as a metrics switch
  while doing nothing.

## 0.1.1

Inherited state, forked from `confluentinc/cp-helm-charts` — a repository that has since
been deleted (the URL 404s), which is why this chart is maintained here rather than
re-vendored.

- Chart `apiVersion: v1` (Helm 2 schema), appVersion 7.5.3
- JMX exporter sidecar on by default, `containers[0]`, on a 2020 JDK 8 image
- No probes, no container security context, no PDB, no Ingress
- `heapOptions` and `metrics.enabled` present in values but read by no template
- All values nested under a `schema_registry` key, unlike the upstream chart these docs
  were originally copied from
