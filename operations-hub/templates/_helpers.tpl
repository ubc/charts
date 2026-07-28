{{/*
Expand the name of the chart.
*/}}
{{- define "operations-hub.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "operations-hub.fullname" -}}
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
{{- define "operations-hub.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "operations-hub.labels" -}}
helm.sh/chart: {{ include "operations-hub.chart" . }}
{{ include "operations-hub.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "operations-hub.selectorLabels" -}}
app.kubernetes.io/name: {{ include "operations-hub.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Return the MariaDB Hostname
*/}}
{{- define "helper.db.host" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.architecture "replication" }}
        {{- printf "%s-db-primary" (include "operations-hub.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- printf "%s-db" (include "operations-hub.fullname" .) -}}
    {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common pod env block — used by both the Deployment and the migration Job
so they stay in sync. Keep this in one place; do not duplicate the env list
into individual templates.
*/}}
{{- define "operations-hub.podEnv" -}}
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name:  {{ include "operations-hub.fullname" . }}-db
      key: username
  value: {{ .Values.db.username }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name:  {{ include "operations-hub.fullname" . }}-db
      key: password
- name: POSTGRES_DB
  value: {{ .Values.db.name }}
- name: POSTGRES_HOST
  value: {{ .Values.db.host }}
- name: WEB_CONCURRENCY
  value: {{ .Values.app.gunicorn.workers | quote }}
- name: GUNICORN_TIMEOUT
  value: {{ .Values.app.gunicorn.timeout | quote }}
- name: FLASK_CONFIG
  value: {{ .Values.app.flask.env | quote }}
- name: FLASK_DEBUG
  value: {{ .Values.app.flask.debug | quote }}
- name: SECRET_KEY
  value: {{ .Values.app.flask.secretKey }}
{{- if .Values.app.smtp.host }}
- name: MAIL_SERVER
  value: {{ .Values.app.smtp.host }}
- name: MAIL_PORT
  value: {{ .Values.app.smtp.port | quote}}
- name: MAIL_USE_TLS
  value: {{ .Values.app.smtp.useTls | quote }}
- name: MAIL_USE_SSL
  value: {{ .Values.app.smtp.useSsl | quote }}
{{- end }}
{{- end -}}
