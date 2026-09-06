{{/* vim: set filetype=mustache: */}}
{{/*
The name of the exporter port. The Service and the container port both reference it, so
it lives here rather than being spelled out twice.
*/}}
{{- define "cp-ksql-server.metricsPortName" -}}metrics{{- end -}}

{{/*
Refuses combinations that would render something that quietly does nothing.
*/}}
{{- define "cp-ksql-server.validateMetrics" -}}
{{- $v := include "cp-ksql-server.values" . | fromYaml -}}
{{- $m := $v.metrics -}}
{{- if and $m.serviceMonitor.enabled $m.podMonitor.enabled -}}
{{- fail "metrics.serviceMonitor.enabled and metrics.podMonitor.enabled are mutually exclusive: both scrape the same exporter, under two job names." -}}
{{- end -}}
{{- if and (or $m.serviceMonitor.enabled $m.podMonitor.enabled) (not $m.enabled) -}}
{{- fail "metrics.serviceMonitor/podMonitor need metrics.enabled: without the exporter sidecar there is nothing listening on the port they point at." -}}
{{- end -}}
{{- end -}}

{{/*
Effective values.

1.2.0 gave the chart the layout every other chart here uses: `image` became a map,
`servicePort` moved under `service`, `prometheus.jmx` became `metrics`, and the
`cp-schema-registry` key — which needed `index .Values "cp-schema-registry"` in every
template because of the dash — became `schemaRegistry`.

The old keys still work. Anything set the old way is mapped onto the new keys and merged
over them, so the legacy spelling wins key by key and anything it leaves out falls
through to the new shape. NOTES.txt warns when any of it is in use.

`image` is the exception and fails loudly instead. Old and new share that one key, so a
legacy string does not sit beside the new map — Helm replaces the map with it, taking
the chart's own tag and pullPolicy defaults with it, and the result would be an image
reference with no tag. There is no shape to merge back from, so the chart says so.

Templates read the result of this, never .Values directly:

    {{- $v := include "cp-ksql-server.values" . | fromYaml }}
*/}}
{{- define "cp-ksql-server.values" -}}
{{- if kindIs "string" .Values.image -}}
{{- fail "image is a map now: set image.repository, and image.tag instead of imageTag. A bare string replaces the whole block, including the tag and pullPolicy defaults." -}}
{{- end -}}
{{- $new := omit .Values "imageTag" "imagePullPolicy" "imagePullSecrets" "servicePort" "prometheus" "cp-schema-registry" -}}
{{- $mapped := dict -}}

{{/* The sibling keys that used to sit next to `image` fold into it. */}}
{{- $image := dict -}}
{{- if hasKey .Values "imageTag" }}{{- $_ := set $image "tag" .Values.imageTag -}}{{- end -}}
{{- if hasKey .Values "imagePullPolicy" }}{{- $_ := set $image "pullPolicy" .Values.imagePullPolicy -}}{{- end -}}
{{- if hasKey .Values "imagePullSecrets" }}{{- $_ := set $image "pullSecrets" (.Values.imagePullSecrets | default list) -}}{{- end -}}
{{- if $image }}{{- $_ := set $mapped "image" (mustMergeOverwrite (deepCopy $new.image) $image) -}}{{- end -}}

{{- if hasKey .Values "servicePort" }}{{- $_ := set $mapped "service" (dict "port" .Values.servicePort) -}}{{- end -}}

{{- $jmx := ((.Values.prometheus | default dict).jmx | default dict) -}}
{{- if $jmx -}}
{{- $metrics := omit $jmx "image" "imageTag" "imagePullPolicy" -}}
{{- $mimage := dict -}}
{{- if hasKey $jmx "image" }}{{- $_ := set $mimage "repository" $jmx.image -}}{{- end -}}
{{- if hasKey $jmx "imageTag" }}{{- $_ := set $mimage "tag" $jmx.imageTag -}}{{- end -}}
{{- if hasKey $jmx "imagePullPolicy" }}{{- $_ := set $mimage "pullPolicy" $jmx.imagePullPolicy -}}{{- end -}}
{{- if $mimage }}{{- $_ := set $metrics "image" (mustMergeOverwrite (deepCopy $new.metrics.image) $mimage) -}}{{- end -}}
{{- $_ := set $mapped "metrics" $metrics -}}
{{- end -}}

{{- $sr := (index .Values "cp-schema-registry") | default dict -}}
{{- if $sr }}{{- $_ := set $mapped "schemaRegistry" $sr -}}{{- end -}}

{{- toYaml (mustMergeOverwrite (deepCopy $new) $mapped) -}}
{{- end -}}

{{/*
True when any legacy key is set, for the NOTES.txt warning.
*/}}
{{- define "cp-ksql-server.usesLegacyValues" -}}
{{- if or (hasKey .Values "imageTag") (hasKey .Values "imagePullPolicy") (hasKey .Values "imagePullSecrets") (hasKey .Values "servicePort") (hasKey .Values "prometheus") (index .Values "cp-schema-registry") -}}
true
{{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "cp-ksql-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cp-ksql-server.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cp-ksql-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified kafka headless name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "cp-ksql-server.cp-kafka-headless.fullname" -}}
{{- $name := "cp-kafka-headless" -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Form the Kafka URL. If Kafka is installed as part of this chart, use k8s service discovery,
else use user-provided URL
*/}}
{{- define "cp-ksql-server.kafka.bootstrapServers" -}}
{{- $v := include "cp-ksql-server.values" . | fromYaml -}}
{{- if $v.kafka.bootstrapServers -}}
{{- $v.kafka.bootstrapServers -}}
{{- else -}}
{{- printf "PLAINTEXT://%s:9092" (include "cp-ksql-server.cp-kafka-headless.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Default Server Pool Id to Release Name but allow it to be overridden.

This names every internal topic the server owns — _confluent-ksql-<serviceId>_command_topic
and the state store topics behind each query — so changing it on a running deployment
orphans all of them and starts again from nothing.
*/}}
{{- define "cp-ksql-server.serviceId" -}}
{{- $v := include "cp-ksql-server.values" . | fromYaml -}}
{{- if $v.serviceId -}}
{{- $v.serviceId -}}
{{- else -}}
{{- .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified schema registry name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "cp-ksql-server.cp-schema-registry.fullname" -}}
{{- $v := include "cp-ksql-server.values" . | fromYaml -}}
{{- $name := default "cp-schema-registry" $v.schemaRegistry.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cp-ksql-server.cp-schema-registry.service-name" -}}
{{- $v := include "cp-ksql-server.values" . | fromYaml -}}
{{- if $v.schemaRegistry.url -}}
{{- $v.schemaRegistry.url -}}
{{- else -}}
{{- printf "http://%s:8081" (include "cp-ksql-server.cp-schema-registry.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
The ServiceAccount to run as. Falls back to `default` only when the chart is told not to
create one and none is named — the pre-1.2.0 behaviour, opted into.
*/}}
{{- define "cp-ksql-server.serviceAccountName" -}}
{{- $v := include "cp-ksql-server.values" . | fromYaml -}}
{{- if $v.serviceAccount.create -}}
{{- default (include "cp-ksql-server.fullname" .) $v.serviceAccount.name -}}
{{- else -}}
{{- default "default" $v.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Selector labels.

These are deliberately the legacy `app`/`release` pair, not app.kubernetes.io/*.
A Deployment's spec.selector is immutable, so changing these would make
`helm upgrade` fail on every existing release with "field is immutable" and
require deleting the Deployment first. The standard labels are added to metadata
instead, where they can change freely.
*/}}
{{- define "cp-ksql-server.selectorLabels" -}}
app: {{ template "cp-ksql-server.name" . }}
release: {{ .Release.Name }}
{{- end -}}

{{/*
Labels applied to object metadata: the legacy set plus the standard ones.
*/}}
{{- define "cp-ksql-server.labels" -}}
{{ include "cp-ksql-server.selectorLabels" . }}
chart: {{ template "cp-ksql-server.chart" . }}
heritage: {{ .Release.Service }}
app.kubernetes.io/name: {{ template "cp-ksql-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ template "cp-ksql-server.name" . }}
app.kubernetes.io/component: ksql-server
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}

{{/*
Object labels plus caller-supplied ones, merged rather than concatenated.

Appending a second block of labels emits a duplicate YAML key whenever the two sets
overlap, and they do: `release` is one of the chart's own labels and is exactly what
kube-prometheus-stack asks a ServiceMonitor to carry. kubectl rejects the result with
"mapping key already defined". Caller labels win.

    {{ include "cp-ksql-server.mergedLabels" (list . $extraLabels) | indent 4 }}
*/}}
{{- define "cp-ksql-server.mergedLabels" -}}
{{- $ctx := index . 0 -}}
{{- $v := include "cp-ksql-server.values" $ctx | fromYaml -}}
{{- $extra := (index . 1) | default dict -}}
{{/* Precedence, lowest first: the chart's own labels, commonLabels, the caller's. */}}
{{- $merged := merge (deepCopy $extra) ($v.commonLabels | default dict) (fromYaml (include "cp-ksql-server.labels" $ctx)) -}}
{{/* Every value goes through toString first: a label value is a string, and an
     appVersion like 8.0 would otherwise render as a number the API server refuses. */}}
{{- $out := dict -}}
{{- range $k, $val := $merged }}{{- $_ := set $out $k (toString $val) -}}{{- end -}}
{{- toYaml $out -}}
{{- end -}}

{{/*
commonAnnotations plus the caller's, merged the same way as labels. Renders nothing
when both are empty, so the caller wraps it:

    {{- with (include "cp-ksql-server.mergedAnnotations" (list . $extra)) }}
    annotations:
    {{ . | indent 4 }}
    {{- end }}
*/}}
{{- define "cp-ksql-server.mergedAnnotations" -}}
{{- $ctx := index . 0 -}}
{{- $v := include "cp-ksql-server.values" $ctx | fromYaml -}}
{{- $extra := (index . 1) | default dict -}}
{{- $merged := merge (deepCopy $extra) ($v.commonAnnotations | default dict) -}}
{{- if $merged -}}
{{- $out := dict -}}
{{- range $k, $val := $merged }}{{- $_ := set $out $k (toString $val) -}}{{- end -}}
{{- toYaml $out -}}
{{- end -}}
{{- end -}}
