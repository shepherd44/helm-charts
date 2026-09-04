{{/* vim: set filetype=mustache: */}}
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
{{- if .Values.schema_registry.kafka.bootstrapServers -}}
{{- .Values.schema_registry.kafka.bootstrapServers -}}
{{- else -}}
{{- printf "PLAINTEXT://%s:9092" (include "cp-kafka-rest.cp-kafka-headless.fullname" .) -}}
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
