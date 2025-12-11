{{/*
Expand the name of the chart.
*/}}
{{- define "hotcrp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "hotcrp.fullname" -}}
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
Create a default fully qualified db name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "hotcrp.db.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "hotcrp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hotcrp.labels" -}}
helm.sh/chart: {{ include "hotcrp.chart" . }}
{{ include "hotcrp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hotcrp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hotcrp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "hotcrp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "hotcrp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the MariaDB Hostname
*/}}
{{- define "hotcrp.databaseHost" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.architecture "replication" }}
        {{- printf "%s-primary" (include "hotcrp.db.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- printf "%s" (include "hotcrp.db.fullname" .) -}}
    {{- end -}}
{{- else -}}
    {{- printf "%s" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Port
*/}}
{{- define "hotcrp.databasePort" -}}
{{- if .Values.db.enabled }}
    {{- printf "3306" -}}
{{- else -}}
    {{- printf "%d" (.Values.externalDatabase.port | int ) -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Database Name
*/}}
{{- define "hotcrp.databaseName" -}}
{{- if .Values.db.enabled }}
    {{- printf "%s" .Values.db.auth.database -}}
{{- else -}}
    {{- printf "%s" .Values.externalDatabase.database -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB User
*/}}
{{- define "hotcrp.databaseUser" -}}
{{- if .Values.db.enabled }}
    {{- printf "%s" .Values.db.auth.username -}}
{{- else -}}
    {{- printf "%s" .Values.externalDatabase.user -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Secret Name
*/}}
{{- define "hotcrp.databaseSecretName" -}}
{{- if .Values.db.enabled }}
    {{- if and .Values.db.auth.existingSecret .Values.db.auth.userPasswordKey -}}
        {{- printf "%s" .Values.db.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s-user-password" (include "hotcrp.db.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
    {{- tpl .Values.externalDatabase.existingSecret $ -}}
{{- else -}}
    {{- printf "%s-externaldb" (include "hotcrp.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Secret Key
*/}}
{{- define "hotcrp.databaseSecretKey" -}}
{{- if .Values.db.enabled }}
    {{- if and .Values.db.auth.existingSecret .Values.db.auth.userPasswordKey -}}
        {{- printf "%s" .Values.db.auth.userPasswordKey -}}
    {{- else -}}
        {{- printf "password-%s" (include "hotcrp.databaseUser" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
    {{- tpl .Values.externalDatabase.existingSecret $ -}}
{{- else -}}
    {{- printf "%s-externaldb" (include "hotcrp.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Root Secret Name
*/}}
{{- define "hotcrp.databaseRootSecretName" -}}
{{- if .Values.db.enabled }}
    {{- if and .Values.db.auth.existingSecret .Values.db.auth.rootPasswordKey -}}
        {{- printf "%s" .Values.db.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s-root" (include "hotcrp.db.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
    {{- tpl .Values.externalDatabase.existingSecret $ -}}
{{- else -}}
    {{- printf "%s-externaldb" (include "hotcrp.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Root Secret Key
*/}}
{{- define "hotcrp.databaseRootSecretKey" -}}
{{- if .Values.db.enabled }}
    {{- if and .Values.db.auth.existingSecret .Values.db.auth.rootPasswordKey -}}
        {{- printf "%s" .Values.db.auth.rootPasswordKey -}}
    {{- else -}}
        {{- printf "password" -}}
    {{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
    {{- tpl .Values.externalDatabase.existingSecret $ -}}
{{- else -}}
    {{- printf "%s-externaldb" (include "hotcrp.fullname" .) -}}
{{- end -}}
{{- end -}}
