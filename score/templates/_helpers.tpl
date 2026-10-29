{{/*
Expand the name of the chart.
*/}}
{{- define "score.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "score.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
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
{{- define "score.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "score.labels" -}}
helm.sh/chart: {{ include "score.chart" . }}
{{ include "score.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "score.selectorLabels" -}}
app.kubernetes.io/name: {{ include "score.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Labels for the migration and prune Job pods. Deliberately not the selector
labels, so the Service never sends traffic to them. Call with
(dict "root" . "component" "migrate").
*/}}
{{- define "score.jobLabels" -}}
helm.sh/chart: {{ include "score.chart" .root }}
app.kubernetes.io/name: {{ include "score.name" .root }}-{{ .component }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end }}

{{/*
Image pull secrets: imagePullSecrets plus image.secrets, which GitLab Auto
Deploy sets to the gitlab-registry-<project> secret it creates.
*/}}
{{- define "score.imagePullSecrets" -}}
{{- with concat (.Values.imagePullSecrets | default list) (.Values.image.secrets | default list) }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Container image, shared by the Deployment and the Jobs.
*/}}
{{- define "score.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end }}

{{/*
Common pod env block — used by the Deployment, the migration Job and the
prune CronJob so they stay in sync. Keep this in one place; do not duplicate
the env list into individual templates.
*/}}
{{- define "score.podEnv" -}}
- name: SCORE_ENV
  value: {{ .Values.app.env | quote }}
{{- if .Values.existingSecret }}
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.existingSecret }}
      key: secret_key
{{- else }}
- name: SECRET_KEY
  value: {{ required "app.secretKey is required (or set existingSecret)" .Values.app.secretKey | quote }}
{{- end }}
- name: POSTGRES_HOST
  value: {{ .Values.db.host | quote }}
- name: POSTGRES_PORT
  value: {{ .Values.db.port | quote }}
- name: POSTGRES_DB
  value: {{ .Values.db.name | quote }}
- name: POSTGRES_USER
  value: {{ .Values.db.username | quote }}
{{- if .Values.existingSecret }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.existingSecret }}
      key: db_password
{{- else }}
- name: POSTGRES_PASSWORD
  value: {{ required "db.password is required (or set existingSecret)" .Values.db.password | quote }}
{{- end }}
- name: RUN_MIGRATIONS
  value: {{ ternary "0" "1" .Values.migrations.enabled | quote }}
- name: GUNICORN_WORKERS
  value: {{ .Values.app.gunicorn.workers | quote }}
- name: GUNICORN_TIMEOUT
  value: {{ .Values.app.gunicorn.timeout | quote }}
- name: TRUST_PROXY_HOPS
  value: {{ .Values.app.trustProxyHops | quote }}
{{- with .Values.app.forwardedAllowIps }}
- name: FORWARDED_ALLOW_IPS
  value: {{ . | quote }}
{{- end }}
- name: DISPLAY_TIMEZONE
  value: {{ .Values.app.displayTimezone | quote }}
{{- with .Values.app.contactEmail }}
- name: CONTACT_EMAIL
  value: {{ . | quote }}
{{- end }}
- name: LOCAL_SIGNIN_ENABLED
  value: {{ .Values.app.localSigninEnabled | quote }}
{{- if .Values.app.smtp.host }}
- name: MAIL_SERVER
  value: {{ .Values.app.smtp.host | quote }}
- name: MAIL_PORT
  value: {{ .Values.app.smtp.port | quote }}
- name: MAIL_USE_TLS
  value: {{ .Values.app.smtp.useTls | quote }}
{{- with .Values.app.smtp.username }}
- name: MAIL_USERNAME
  value: {{ . | quote }}
{{- end }}
{{- if .Values.existingSecret }}
- name: MAIL_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.existingSecret }}
      key: mail_password
      optional: true
{{- else if .Values.app.smtp.password }}
- name: MAIL_PASSWORD
  value: {{ .Values.app.smtp.password | quote }}
{{- end }}
{{- with .Values.app.smtp.sender }}
- name: MAIL_DEFAULT_SENDER
  value: {{ . | quote }}
{{- end }}
{{- end }}
{{- with .Values.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}
