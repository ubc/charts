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
Directory the SAML SP material is mounted into.

The cert, key and IdP metadata paths are all derived from this one definition so
the env vars the app reads and the volume that supplies the files cannot drift
apart — a mismatch between them surfaces only as a 404 on /auth/saml/metadata,
which is expensive to diagnose.
*/}}
{{- define "operations-hub.saml.mountPath" -}}/app/instance/saml{{- end -}}

{{/*
IdP metadata lives in its own directory, not alongside the SP keypair: the keypair
mount is read-only, and the auto-fetch init container has to write this file.
*/}}
{{- define "operations-hub.saml.idpDir" -}}/app/instance/saml-idp{{- end -}}

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
{{- if .Values.app.saml.enabled }}
{{- $samlDir := include "operations-hub.saml.mountPath" . }}
- name: SAML_SP_ENTITY_ID
  value: {{ .Values.app.saml.spEntityId | quote }}
- name: SAML_SP_BASE_URL
  value: {{ .Values.app.saml.baseUrl | quote }}
- name: SAML_SP_CERT_PATH
  value: {{ printf "%s/sp.crt" $samlDir | quote }}
- name: SAML_SP_KEY_PATH
  value: {{ printf "%s/sp.key" $samlDir | quote }}
{{- /*
  Only set once UBC IAM has returned their metadata. Until then the four SP keys
  above are enough to serve /auth/saml/metadata, which is what they need in order
  to produce it — requiring their file first would deadlock the exchange.
*/}}
{{- if or .Values.app.saml.idpMetadata .Values.app.saml.idpMetadataUrl }}
- name: SAML_IDP_METADATA_PATH
  value: {{ printf "%s/idp-metadata.xml" (include "operations-hub.saml.idpDir" .) | quote }}
{{- end }}
{{- with .Values.app.saml.contact.name }}
- name: SAML_CONTACT_NAME
  value: {{ . | quote }}
{{- end }}
{{- with .Values.app.saml.contact.email }}
- name: SAML_CONTACT_EMAIL
  value: {{ . | quote }}
{{- end }}
{{- if .Values.app.saml.metadataValidDays }}
- name: SAML_METADATA_VALID_DAYS
  value: {{ .Values.app.saml.metadataValidDays | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Fail the render rather than deploy an auto-fetch that would accept any document.
UBC publishes unsigned metadata, so the pinned entity id is the only integrity
check there is -- silently omitting it is worse than a loud template error.
*/}}
{{- define "operations-hub.saml.validate" -}}
{{- if and .Values.app.saml.enabled .Values.app.saml.idpMetadataUrl }}
{{- if not (trim (default "" .Values.app.saml.idpEntityId)) }}
{{- fail "app.saml.idpEntityId is required when app.saml.idpMetadataUrl is set" }}
{{- end }}
{{- end }}
{{- end -}}
