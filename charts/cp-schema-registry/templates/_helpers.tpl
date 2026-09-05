{{/* vim: set filetype=mustache: */}}
{{/*
Effective values.

1.0.0 flattened the layout: everything used to live under `schema_registry`. That block
still works: anything set there is mapped onto the new keys and merged over them, so the
legacy block wins key by key and anything it leaves out falls through to the new shape.
NOTES.txt warns when it is in use.

Templates read the result of this, never .Values directly:

    {{- $v := include "cp-schema-registry.values" . | fromYaml }}
*/}}
{{- define "cp-schema-registry.values" -}}
{{- $new := omit .Values "schema_registry" -}}
{{- $legacy := .Values.schema_registry | default dict -}}
{{- if not $legacy -}}
{{- toYaml $new -}}
{{- else -}}
{{/* Keys whose name or shape changed have to be moved by hand; everything else keeps
     its name and comes across in the plain merge below. */}}
{{- $mapped := omit $legacy "image" "imageTag" "imagePullPolicy" "imagePullSecrets" "servicePort" "securityContext" "prometheus" "tests" -}}
{{- $image := dict -}}
{{- if hasKey $legacy "image" }}{{- $_ := set $image "repository" $legacy.image -}}{{- end -}}
{{- if hasKey $legacy "imageTag" }}{{- $_ := set $image "tag" $legacy.imageTag -}}{{- end -}}
{{- if hasKey $legacy "imagePullPolicy" }}{{- $_ := set $image "pullPolicy" $legacy.imagePullPolicy -}}{{- end -}}
{{- if hasKey $legacy "imagePullSecrets" }}{{- $_ := set $image "pullSecrets" ($legacy.imagePullSecrets | default list) -}}{{- end -}}
{{- if $image }}{{- $_ := set $mapped "image" (mustMergeOverwrite (deepCopy $new.image) $image) -}}{{- end -}}
{{- if hasKey $legacy "servicePort" }}{{- $_ := set $mapped "service" (dict "port" $legacy.servicePort) -}}{{- end -}}
{{- if hasKey $legacy "securityContext" }}{{- $_ := set $mapped "podSecurityContext" $legacy.securityContext -}}{{- end -}}
{{- $jmx := (($legacy.prometheus | default dict).jmx | default dict) -}}
{{- if $jmx -}}
{{- $metrics := omit $jmx "image" "imageTag" "imagePullPolicy" -}}
{{- $mimage := dict -}}
{{- if hasKey $jmx "image" }}{{- $_ := set $mimage "repository" $jmx.image -}}{{- end -}}
{{- if hasKey $jmx "imageTag" }}{{- $_ := set $mimage "tag" $jmx.imageTag -}}{{- end -}}
{{- if hasKey $jmx "imagePullPolicy" }}{{- $_ := set $mimage "pullPolicy" $jmx.imagePullPolicy -}}{{- end -}}
{{- if $mimage }}{{- $_ := set $metrics "image" (mustMergeOverwrite (deepCopy $new.metrics.image) $mimage) -}}{{- end -}}
{{- $_ := set $mapped "metrics" $metrics -}}
{{- end -}}
{{- $tests := $legacy.tests | default dict -}}
{{- if $tests -}}
{{- $t := omit $tests "image" "imageTag" "imagePullPolicy" "imagePullSecrets" -}}
{{- $timage := dict -}}
{{- if hasKey $tests "image" }}{{- $_ := set $timage "repository" $tests.image -}}{{- end -}}
{{- if hasKey $tests "imageTag" }}{{- $_ := set $timage "tag" $tests.imageTag -}}{{- end -}}
{{- if hasKey $tests "imagePullPolicy" }}{{- $_ := set $timage "pullPolicy" $tests.imagePullPolicy -}}{{- end -}}
{{- if hasKey $tests "imagePullSecrets" }}{{- $_ := set $timage "pullSecrets" ($tests.imagePullSecrets | default list) -}}{{- end -}}
{{- if $timage }}{{- $_ := set $t "image" (mustMergeOverwrite (deepCopy $new.tests.image) $timage) -}}{{- end -}}
{{- $_ := set $mapped "tests" $t -}}
{{- end -}}
{{- toYaml (mustMergeOverwrite (deepCopy $new) $mapped) -}}
{{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "cp-schema-registry.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cp-schema-registry.fullname" -}}
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
{{- define "cp-schema-registry.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified kafka headless name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "cp-kafka-rest.cp-kafka-headless.fullname" -}}
{{- $name := "cp-kafka-headless" -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Form the Kafka URL. If Kafka is installed as part of this chart, use k8s service discovery,
else use user-provided URL
*/}}
{{- define "cp-schema-registry.kafka.bootstrapServers" -}}
{{- $v := include "cp-schema-registry.values" . | fromYaml -}}
{{- if $v.kafka.bootstrapServers -}}
{{- $v.kafka.bootstrapServers -}}
{{- else -}}
{{- printf "PLAINTEXT://%s:9092" (include "cp-kafka-rest.cp-kafka-headless.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
The ServiceAccount to run as. Falls back to `default` only when the chart is told
not to create one and none is named — i.e. the pre-0.7.0 behaviour, opted into.
*/}}
{{- define "cp-schema-registry.serviceAccountName" -}}
{{- $v := include "cp-schema-registry.values" . | fromYaml -}}
{{- if $v.serviceAccount.create -}}
{{- default (include "cp-schema-registry.fullname" .) $v.serviceAccount.name -}}
{{- else -}}
{{- default "default" $v.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Default GroupId to Release Name but allow it to be overridden
*/}}
{{- define "cp-schema-registry.groupId" -}}
{{- if .Values.overrideGroupId -}}
{{- .Values.overrideGroupId -}}
{{- else -}}
{{- .Release.Name -}}
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
{{- define "cp-schema-registry.selectorLabels" -}}
app: {{ template "cp-schema-registry.name" . }}
release: {{ .Release.Name }}
{{- end -}}

{{/*
Labels applied to object metadata: the legacy set plus the standard ones.
*/}}
{{- define "cp-schema-registry.labels" -}}
{{ include "cp-schema-registry.selectorLabels" . }}
chart: {{ template "cp-schema-registry.chart" . }}
heritage: {{ .Release.Service }}
app.kubernetes.io/name: {{ template "cp-schema-registry.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ template "cp-schema-registry.name" . }}
app.kubernetes.io/component: schema-registry
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}


{{/*
Schema Registry config that ends up as SCHEMA_REGISTRY_* env.

The chart sets a few keys itself. Rendering those separately from
configurationOverrides meant a user who set the same key got the variable twice —
legal, last-wins, but undefined-looking. Merge instead, with configurationOverrides
winning, so every key is emitted exactly once.

host.name is not here: it is a fieldRef, not a value. The deployment emits it only
when configurationOverrides does not set it.
*/}}
{{- define "cp-schema-registry.config" -}}
{{- $v := include "cp-schema-registry.values" . | fromYaml -}}
{{- $overrides := $v.configurationOverrides | default dict -}}
{{- $managed := dict
      "listeners" (printf "http://0.0.0.0:%v" $v.service.port)
      "kafkastore.bootstrap.servers" (include "cp-schema-registry.kafka.bootstrapServers" .)
      "kafkastore.group.id" (include "cp-schema-registry.groupId" .)
-}}
{{/* Setting both spellings leaves it ambiguous which one Schema Registry honours,
     so the deprecated one being present explicitly means the chart stays out. */}}
{{- if not (hasKey $overrides "master.eligibility") -}}
{{- $_ := set $managed "leader.eligibility" ($v.leaderEligibility | toString) -}}
{{- end -}}
{{- toYaml (merge (deepCopy $overrides) $managed) -}}
{{- end -}}

{{/*
Config keys carrying @Deprecated in Schema Registry 8.3.0, with their replacement.
Still accepted, so this only drives a warning in NOTES.txt.
*/}}
{{- define "cp-schema-registry.deprecatedConfig" -}}
master.eligibility: leader.eligibility
avro.compatibility.level: schema.compatibility.level
kafkastore.connection.url: kafkastore.bootstrap.servers
schema.registry.resource.extension.class: resource.extension.class
schema.registry.inter.instance.protocol: inter.instance.protocol
ssl.client.auth: ssl.client.authentication
{{- end -}}
