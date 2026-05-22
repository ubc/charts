{{/*
Expand the name of the chart.
*/}}
{{- define "ladistra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ladistra.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ladistra.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ladistra.labels" -}}
helm.sh/chart: {{ include "ladistra.chart" . }}
{{ include "ladistra.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ladistra.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ladistra.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Return the MariaDB Hostname
*/}}
{{- define "helper.db.host" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.architecture "replication" }}
        {{- printf "%s-db-primary" (include "ladistra.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- printf "%s-db" (include "ladistra.fullname" .) -}}
    {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common pod env block — used by both the Deployment and the migration Job
so they stay in sync. Keep this in one place; do not duplicate the env list
into individual templates.
*/}}
{{- define "ladistra.podEnv" -}}
- name: POSTGRES_USER
  value: {{ .Values.db.username }}
- name: POSTGRES_PASSWORD
  value: {{ .Values.db.password }}
- name: POSTGRES_DB
  value: {{ .Values.db.name }}
- name: POSTGRES_HOST
  value: {{ .Values.db.host }}
- name: FLASK_APP
  value: {{ .Values.app.flask.app }}
- name: FLASK_ENV
  value: {{ .Values.app.flask.env }}
- name: FLASK_DEBUG
  value: {{ .Values.app.flask.debug }}
- name: SECRET_KEY
  value: {{ .Values.app.flask.secretKey }}
{{- if .Values.app.smtp.host }}
- name: MAIL_SERVER
  value: {{ .Values.app.smtp.host }}
{{- end }}
- name: MAIL_PORT
  value: {{ .Values.app.smtp.port | quote}}
- name: MAIL_USE_TLS
  value: {{ .Values.app.smtp.useTls | quote }}
- name: MAIL_USE_SSL
  value: {{ .Values.app.smtp.useSsl | quote }}
- name: MAIL_SUPPRESS_SEND
  value: {{ .Values.app.smtp.suppressSend | quote }}
{{- if .Values.app.smtp.sender }}
- name: MAIL_DEFAULT_SENDER
  value: {{ .Values.app.smtp.sender | quote }}
{{- end }}
{{- end -}}
