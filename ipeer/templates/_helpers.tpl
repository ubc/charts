{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "ipeer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ipeer.fullname" -}}
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
Common labels
*/}}
{{- define "ipeer.labels" -}}
{{ include "ipeer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
stage: {{ .Values.stage }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ipeer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ipeer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ipeer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ipeer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "ipeer.db.fullname" -}}
{{- if .Values.db.fullnameOverride -}}
{{- .Values.db.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "db" .Values.db.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Hostname
*/}}
{{- define "ipeer.databaseHost" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.architecture "replication" }}
        {{- printf "%s-primary" (include "ipeer.db.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- printf "%s" (include "ipeer.db.fullname" .) -}}
    {{- end -}}
{{- else -}}
    {{- printf "%s" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB User
*/}}
{{- define "ipeer.databaseUser" -}}
{{- if .Values.db.enabled }}
    {{- printf "%s" .Values.db.auth.username -}}
{{- else -}}
    {{- printf "%s" .Values.externalDatabase.user -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Secret Name
*/}}
{{- define "ipeer.databaseSecretName" -}}
{{- if .Values.db.enabled }}
    {{- if and .Values.db.auth.existingSecret .Values.db.auth.userPasswordKey -}}
        {{- printf "%s" .Values.db.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s-user-password" (include "ipeer.db.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
    {{- tpl .Values.externalDatabase.existingSecret $ -}}
{{- else -}}
    {{- printf "%s-externaldb" (include "ipeer.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Secret Key
*/}}
{{- define "ipeer.databaseSecretKey" -}}
{{- if .Values.db.enabled }}
    {{- if and .Values.db.auth.existingSecret .Values.db.auth.userPasswordKey -}}
        {{- printf "%s" .Values.db.auth.userPasswordKey -}}
    {{- else -}}
        {{- printf "password-%s" (include "ipeer.databaseUser" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
    {{- tpl .Values.externalDatabase.existingSecret $ -}}
{{- else -}}
    {{- printf "%s-externaldb" (include "ipeer.fullname" .) -}}
{{- end -}}
{{- end -}}
