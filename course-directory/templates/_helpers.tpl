{{/*
Expand the name of the chart.
*/}}
{{- define "ltic-access-request.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ltic-access-request.fullname" -}}
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
{{- define "ltic-access-request.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ltic-access-request.labels" -}}
helm.sh/chart: {{ include "ltic-access-request.chart" . }}
{{ include "ltic-access-request.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ltic-access-request.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ltic-access-request.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Return the MariaDB Hostname
*/}}
{{- define "helper.db.host" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.architecture "replication" }}
        {{- printf "%s-db-primary" (include "ltic-access-request.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- printf "%s-db" (include "ltic-access-request.fullname" .) -}}
    {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common pod env block — used by both the Deployment and the migration Job
so they stay in sync. Keep this in one place; do not duplicate the env list
into individual templates.
*/}}
{{- define "ltic-access-request.podEnv" -}}
- name: POSTGRES_USER
  value: {{ .Values.db.username }}
- name: POSTGRES_PASSWORD
  value: {{ .Values.db.password }}
- name: POSTGRES_DB
  value: {{ .Values.db.name }}
- name: POSTGRES_HOST
  value: {{ .Values.db.host }}
- name: DATABASE_URL
  value: {{ printf "postgresql+psycopg://%s:%s@%s:5432/%s" .Values.db.username .Values.db.password .Values.db.host .Values.db.name | quote }}
- name: DB_PASSWORD
  value: {{ .Values.db.password }}
- name: FLASK_ENV
  value: {{ .Values.app.flask.env }}
- name: SECRET_KEY
  value: {{ .Values.app.flask.secretKey }}
- name: SMTP_HOST
  value: {{ .Values.app.smtp.host }}
- name: SMTP_PORT
  value: {{ .Values.app.smtp.port | quote}}
- name: SMTP_USE_TLS
  value: {{ .Values.app.smtp.useTls | quote }}
- name: SMTP_USER
  value: {{ .Values.app.smtp.user }}
- name: SMTP_PASSWORD
  value: {{ .Values.app.smtp.password }}
- name: SMTP_FROM
  value: {{ .Values.app.smtp.from }}
- name: ALLOWED_EMAIL_DOMAINS
  value: {{ .Values.app.smtp.allowedEmailDomains }}
- name: BASE_URL
  value: https://{{ .Values.ingress.host }}
{{- if .Values.saml.enabled }}
{{- $samlBaseUrl := .Values.saml.serviceProvider.baseUrl | default (printf "https://%s" .Values.ingress.host) }}
{{- $samlEntityId := .Values.saml.serviceProvider.entityId | default (printf "%s/auth/saml/metadata" $samlBaseUrl) }}
- name: SAML_ENABLED
  value: "true"
- name: SAML_SP_BASE_URL
  value: {{ $samlBaseUrl | quote }}
- name: SAML_SP_ENTITY_ID
  value: {{ $samlEntityId | quote }}
- name: SAML_SP_CERT_PATH
  value: {{ printf "%s/%s" .Values.saml.serviceProvider.certMountPath .Values.saml.serviceProvider.certFilename | quote }}
- name: SAML_SP_KEY_PATH
  value: {{ printf "%s/%s" .Values.saml.serviceProvider.certMountPath .Values.saml.serviceProvider.keyFilename | quote }}
- name: SAML_IDP_METADATA_PATH
  value: {{ printf "%s/%s" .Values.saml.serviceProvider.certMountPath .Values.saml.serviceProvider.metadataFilename | quote }}
- name: SAML_CONTACT_NAME
  value: {{ .Values.saml.contact.name | quote }}
- name: SAML_CONTACT_EMAIL
  value: {{ .Values.saml.contact.email | quote }}
{{- end }}
{{- end -}}
