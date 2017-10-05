{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "mediawiki.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "mediawiki.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "mediawiki.db.fullname" -}}
{{- $name := printf "%s-%s" .Release.Name "db" -}}
{{- default $name .Values.db.service.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "common_labels" }}
app: {{ template "mediawiki.fullname" . }}
stage: {{ .Values.stage }}
chart: {{ print .Chart.Name "-" .Chart.Version | replace "+" "_" | quote }}
release: {{ .Release.Name | quote }}
heritage: {{ .Release.Service | quote }}
{{- if .Values.CI_PIPELINE_ID }}
autodeployed: "true"
pipeline_id: "{{  .Values.CI_PIPELINE_ID }}"
{{- end }}
{{- if .Values.CI_BUILD_ID }}
build_id: "{{ .Values.CI_BUILD_ID }}"
{{- end }}
{{- end }}
