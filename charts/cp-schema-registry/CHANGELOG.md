# Changelog

Chart versions of `cp-schema-registry`. The chart's own line, not Confluent's — see
[docs/schema-registry-versions.md](docs/schema-registry-versions.md) for the application
side.

Forked from `confluentinc/cp-helm-charts`, a repository that no longer exists, so there is
no upstream changelog to keep alongside this one.

Each release is tagged in git as `cp-schema-registry-<version>`.

## 1.4.0

- **`commonLabels` and `commonAnnotations`**, applied to every object the chart renders
  — Deployment, Service, ServiceAccount, ConfigMap, PodDisruptionBudget, Ingress,
  HTTPRoute, the monitors, and the `helm test` pod.
- **Per-resource metadata** on the objects that had none: `deployment.labels` and
  `.annotations`, `podLabels` (`podAnnotations` already existed), `service.labels` and
  `.annotations`, `podDisruptionBudget.labels` and `.annotations`. The ServiceAccount,
  Ingress, HTTPRoute and monitors already took their own and now merge the common ones
  underneath.

  Precedence, lowest first: the chart's own labels, then `commonLabels`, then the
  per-resource key. Same for annotations, minus the chart's own.

  **The Deployment's `spec.selector` is untouched by all of it.** A selector is
  immutable, so it keeps only the legacy `app`/`release` pair — adding a label there
  would break `helm upgrade` on every existing release.

Rendered output with default values is unchanged apart from label ordering: objects that
now go through the merge helper emit their labels alphabetically, and
`app.kubernetes.io/version` loses its quotes where the value does not need them. Same
labels, same values.

## 1.3.0

- **`httpRoute`.** An `HTTPRoute` for clusters running a Gateway API controller, off by
  default. Deliberately **independent of `ingress`** rather than an either/or switch:
  during a migration people run both, and separate flags mean retiring one later is not a
  breaking change.

  Left alone, `rules` routes every path to the chart's own Service — the same thing the
  Ingress does — and setting it hands the routing over completely. `parentRefs` is
  required, because an HTTPRoute with no parent attaches to no Gateway and silently routes
  nothing.

  Nothing is auto-detected. The object renders on any cluster; whether it does anything
  depends on the CRDs and a controller being installed. `gateway.networking.k8s.io/v1`
  needs Kubernetes 1.25, which the README's version table now records alongside the rest.

## 1.2.0

Nothing here is on by default; a release that does not set these renders exactly what
1.1.0 did.

- **`topologySpreadConstraints`.** A pass-through, empty by default. The chart already
  had `affinity` and a PodDisruptionBudget, but without a spread three replicas can land
  on one node — and then the budget protects nothing against a drain of it. Both keys
  stay: a pod spec can carry both, and they answer different questions ("roughly
  balanced across zones" versus "never two on one node").

- **`networkPolicy`.** Off by default, because a policy that is wrong takes the release
  down and reads like a Schema Registry fault. Enabling it writes an *ingress* policy —
  the REST port, the exporter port when `metrics.enabled`, nothing else — which cannot
  break the pod's own outbound traffic.

  Egress is a second switch, because adding `Egress` to `policyTypes` denies everything
  the rules do not name, Kafka included, and the chart cannot locate Kafka for you:
  `kafka.bootstrapServers` is a hostname string, not a selector or a CIDR. `allowDNS` is
  on by default — an egress policy without DNS cannot resolve the bootstrap servers, and
  that failure looks like a Kafka outage.

- **`metrics.mode`.** `sidecar` (default, unchanged) or `native`, which moves the
  exporter to an init container with `restartPolicy: Always` — a Kubernetes sidecar
  container, started before the main container and stopped after it, instead of racing
  it in both directions. **Needs Kubernetes 1.29+.** Below that the API server drops the
  unknown field and the exporter becomes an init container that never exits, so the pod
  hangs in `Init:0/1` with nothing in the events to explain it. The chart cannot check
  this for you — reading the cluster version at render time makes `helm template` and a
  server-side GitOps render disagree — so it is a deliberate value.

  The exporter container is now defined once, in a helper, and rendered into either
  position.

- **README: a Kubernetes version table.** Which values need which version, and what to
  use instead below it — `matchLabelKeys` and `minDomains` inside spread constraints
  (1.27/1.30), `metrics.mode: native` (1.29), `endPort` in network policy rules (1.25),
  Gateway API CRDs (1.23/1.25). The chart's floor is 1.22 and everything it renders by
  default works there; this is for the things you switch on.

## 1.1.0

- **ServiceMonitor, PodMonitor and PrometheusRule** under `metrics`, all off by default.
  The chart previously shipped only `prometheus.io/scrape` annotations, which a
  Prometheus Operator install ignores — so the exporter could be enabled and scraped by
  nothing, which is the state this chart was in. The annotations are still emitted, now
  behind `metrics.scrapeAnnotations`, so a release does not end up discovered twice.

  Both monitors reference the exporter port **by name**, from a single helper the
  Service and the container port also use, so the three cannot drift apart. The
  exporter's container port is named for the first time — that is a visible change in
  the rendered pod for anyone running the sidecar.

  Two combinations now fail at render time instead of quietly doing nothing: a monitor
  without `metrics.enabled` (nothing is listening), and both monitors at once (one
  exporter scraped under two job names). `prometheusRule.enabled` with no rules fails
  too; the chart ships no default alerts, because what is worth alerting on depends on
  the deployment.

- **`values.schema.json`.** Helm now validates values on install, upgrade, lint and
  template. Permissive at the top level — unknown keys are fine, since people carry
  extra values through wrappers — and strict inside the maps the chart owns, which is
  where typos happen: `--set image.repo=x` is now an error rather than a successful
  install of the defaults.

- **Fixed: caller-supplied labels were appended, not merged.** `ingress.labels`,
  `serviceAccount.labels` and now the monitors' labels were emitted after the chart's
  own, so setting one the chart already sets produced a duplicate YAML key and kubectl
  refused the manifest with "mapping key already defined". This is not hypothetical for
  the monitors: kube-prometheus-stack selects on `release`, which is one of the chart's
  own labels. Caller labels now win, and every label value is stringified so an
  `appVersion` like `8.0` cannot render as a number.

  Side effect on the objects that take caller labels — the ServiceAccount and the
  Ingress — is that their `metadata.labels` now render in alphabetical order. Same
  labels, same values, different order in the diff.

## 1.0.0

Breaking, in the values only: the rendered manifests are unchanged. Every values file
that worked against 0.7.0 still works, because the old `schema_registry` block is mapped
onto the new keys — but it is deprecated and the chart says so at install time.

Everything moves up one level. `schema_registry.replicaCount` is `replicaCount`,
`schema_registry.resources` is `resources`, and so on for the whole file. Five things
changed shape as well as depth:

| 0.7.0 | 1.0.0 |
|---|---|
| `schema_registry.image` (a string) | `image.repository` |
| `schema_registry.imageTag` | `image.tag` |
| `schema_registry.imagePullPolicy` | `image.pullPolicy` |
| `schema_registry.imagePullSecrets` | `image.pullSecrets` |
| `schema_registry.servicePort` | `service.port` |
| `schema_registry.securityContext` | `podSecurityContext` |
| `schema_registry.prometheus.jmx` | `metrics` |
| `schema_registry.tests.image` (a string) | `tests.image.repository` |

The old layout was the reason `--set image.tag=8.0.0` silently installed the defaults:
`--set` on a key a chart does not have is accepted without complaint. It was also a
standing argument about which convention a new key should follow, and the list of keys
was about to grow — ServiceMonitor alone adds a dozen.

The deprecated block wins key by key: what it sets overrides the same setting in the new
shape, what it leaves out falls through. So a values file can be migrated a piece at a
time, and `NOTES.txt` warns while any of it is still in use.

Verified by rendering: 0.7.0 and 1.0.0 produce byte-identical manifests apart from the
`chart` label — with defaults, with a full 0.7.0 values file, with the legacy keys set on
the command line, and with their new-shape equivalents. CI installs the deprecated layout
on a real cluster (`ci/legacy-values.yaml`) rather than trusting the template tests alone.

## 0.7.0

Absorbs 0.6.0, which was tagged in the changelog but never packaged into `docs/` —
there is no published 0.6.0 to be immutable about, so the two are one release.

Identity and secrets:

- **ServiceAccount** (`schema_registry.serviceAccount`, created by default). The pods ran
  as the namespace's `default` ServiceAccount with its API token mounted at
  `/var/run/secrets/kubernetes.io/serviceaccount`. Schema Registry talks to Kafka and
  never to the Kubernetes API, so that token was a credential nothing used;
  `automountServiceAccountToken` is now false. The ServiceAccount is also where cloud
  identity annotations go (EKS IRSA, GKE Workload Identity), which could not be put on
  the shared `default` without affecting every other workload in the namespace.
- **`envFrom`, `extraVolumes`, `extraVolumeMounts`.** Everything in
  `configurationOverrides` is rendered as a literal env value, so connecting to a real
  Kafka meant `kafkastore.sasl.jaas.config` — which contains `password="..."` — and the
  truststore and keystore passwords sitting in plaintext in the Deployment spec, readable
  with `kubectl get deploy -o yaml` and committed verbatim into any GitOps repo. There
  was no way to avoid it. The server container also had no `volumeMounts` at all, so a
  JKS truststore could not be mounted.

Pass-throughs, all empty by default: `initContainers`, `extraContainers`,
`priorityClassName`, `terminationGracePeriodSeconds`.

Fixes:

- **The raw JMX port is declared whenever `jmx.port` is set**, instead of only when the
  exporter sidecar is enabled. `JMX_PORT` was always set on the container, so the JVM was
  listening either way; the gate only hid the port from anyone attaching jconsole without
  also running a second JVM. Existing releases gain a `containerPort: 5555` declaration.
- **`schemaRegistryOpts` exists in `values.yaml`.** The template has always rendered
  `SCHEMA_REGISTRY_OPTS` from it and the README documented it, but the key was missing
  from the values file, so it was invisible to anyone reading it.

Metadata: `home`, `maintainers` and Artifact Hub annotations in `Chart.yaml`, and a
`LICENSE.md` — upstream shipped no per-chart license file, so this carries
`confluentinc/cp-helm-charts`' `LICENSE` verbatim, recovered from a surviving fork after
the original repository was deleted. `images`
there is documentation for this chart — it bundles no `common` library, so nothing
enforces it — but it is what an installer reads, so it tracks `values.yaml`.

Also documented: this chart ships no HPA or KEDA support, on purpose. See the README.

### From 0.6.0

Nothing in this half changes the running workload. Its only new object is the `helm test`
hook, which Helm creates on `helm test` and never on install or upgrade. This half is
about the chart being checkable.

- **`kubeVersion: ">=1.22.0-0"`.** The floor is now declared, so Helm refuses to install
  on anything older instead of failing at apply time. Everything the chart emits already
  existed in 1.22 — `apps/v1`, `networking.k8s.io/v1` Ingress, `policy/v1`
  PodDisruptionBudget, `seccompProfile` — so this records a fact rather than changing one.
  The `-0` suffix makes pre-release cluster versions such as `1.22.0-alpha.3` compare
  correctly.
- **`helm test` hook** (`schema_registry.tests`, on by default). A pod that curls
  `/subjects` on the release's own Service. It runs only on `helm test`, and proves what
  a successful install does not: the Service selector matches the pods, the port name
  resolves, and the Kafka store is readable. Its `securityContext` pins a numeric
  `runAsUser`, because `curlimages/curl` declares a named user and a kubelet cannot
  verify a name against `runAsNonRoot` — it fails the container with
  `CreateContainerConfigError` instead of starting it.
- **`.helmignore` covers `ci/`, `tests/` and `.omc/`.** The CI values files and the
  template unit tests are repository content, not part of the package. The patterns are
  anchored with a leading slash on purpose — a bare `tests/` would also drop
  `templates/tests/`, i.e. the test hook, out of the tarball.

Repository-level, outside the chart: `ct lint` (which enforces this version bump),
`helm-unittest` suites under `tests/`, `kubeconform` validation at 1.22 and 1.31, and
`ct install` plus `helm test` on KinD against a single-node Kafka. See the CI workflow.

## 0.5.0

Acting on the field inventory in
[docs/schema-registry-versions.md](docs/schema-registry-versions.md).

- **`master.eligibility` → `leader.eligibility`.** The chart hardcoded
  `SCHEMA_REGISTRY_MASTER_ELIGIBILITY`, which carries `@Deprecated` upstream. It is now
  `leader.eligibility`, exposed as `schema_registry.leaderEligibility` rather than fixed
  at `true`. Both spellings are still registered at 8.3.1, so this is not a forced move —
  it just stops the chart from being the thing that uses the deprecated one.
- **`configurationOverrides` no longer duplicates env.** The keys the chart sets itself
  and the user's overrides are merged before rendering, overrides winning, so each
  variable is emitted once. Previously setting e.g. `kafkastore.group.id` produced
  `SCHEMA_REGISTRY_KAFKASTORE_GROUP_ID` twice; Kubernetes takes the last, so it worked by
  accident.
- **`host.name` is overridable.** It defaults to the pod IP via fieldRef; setting
  `host.name` in `configurationOverrides` now replaces that instead of colliding with it.
- **Deprecation warning at install time.** `NOTES.txt` checks `configurationOverrides`
  against the six keys marked `@Deprecated` in 8.3.0 and names the replacement for each.
  Setting `master.eligibility` explicitly also suppresses the chart's `leader.eligibility`
  so the two spellings cannot disagree.
- **NOTES.txt rewritten.** It said only that this is a modified Confluent chart. It now
  gives the REST endpoint, the port-forward, where schemas live, and warns that an
  enabled Ingress exposes a writable API on a service with no authentication.

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
