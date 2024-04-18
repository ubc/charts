{{/*
Expand the name of the chart.
*/}}
{{- define "webwork.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
For calling a template with subchart context
From https://github.com/helm/helm/issues/4535#issuecomment-477778391
*/}}
{{- define "call-nested" }}
{{- $dot := index . 0 }}
{{- $subchart := index . 1 | splitList "." }}
{{- $template := index . 2 }}
{{- $values := $dot.Values }}
{{- range $subchart }}
{{- $values = index $values . }}
{{- end }}
{{- include $template (dict "Chart" (dict "Name" (last $subchart)) "Values" $values "Release" $dot.Release "Capabilities" $dot.Capabilities) }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "webwork.fullname" -}}
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
{{- define "webwork.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "webwork.labels" -}}
helm.sh/chart: {{ include "webwork.chart" . }}
{{ include "webwork.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "webwork.selectorLabels" -}}
app.kubernetes.io/name: {{ include "webwork.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "webwork.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "webwork.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "common_labels" }}
app: {{ template "webwork.fullname" . }}
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

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "app.db.fullname" -}}
{{- if .Values.db.disableExternal }}
{{- include "call-nested" (list . "db" "mariadb.primary.fullname") | default .Values.db.service.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- if .Values.db.service.name}}
{{- printf "%s" .Values.db.service.name -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "db" -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{/* webwork container spec */}}
{{- define "webwork.app.spec" }}
securityContext:
  {{- toYaml .Values.securityContext | nindent 12 }}
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
imagePullPolicy: {{ .Values.image.pullPolicy }}
env:
- name: WEBWORK_DB_DRIVER
  value: {{ .Values.db.db.driver | quote }}
- name: WEBWORK_DB_HOST
  value: {{ template "app.db.fullname" . }}
- name: WEBWORK_DB_PORT
  value: {{ .Values.db.service.port | quote }}
- name: WEBWORK_DB_NAME
  value: {{ .Values.db.auth.database | quote }}
- name: WEBWORK_DB_USER
  value: {{ .Values.db.auth.username | quote }}
- name: WEBWORK_DB_PASSWORD
  valueFrom:
    secretKeyRef:
    {{- if .Values.db.disableExternal }}
      name: {{ template "app.db.fullname" . }}
      key: mariadb-password
    {{- else }}
      name: {{ template "webwork.fullname" . }}
      key: db_password
    {{- end }}
- name: WEBWORK_ROOT_URL
  value: {{ .Values.rootUrl | quote }}
- name: WEBWORK_TIMEZONE
  value: {{ .Values.timezone | quote }}
- name: R_HOST
  value: {{ template "webwork.fullname" . }}-r
- name: SYSTEM_TIMEZONE
  value: {{ .Values.systemTimezone | quote }}
- name: WEBWORK_SMTP_SERVER
  value: {{ .Values.smtp.server | quote }}
- name: WEBWORK_SMTP_SENDER
  value: {{ .Values.smtp.sender | quote }}
- name: LOG_LEVEL
  value: {{ .Values.shibd.log_level | quote }}
- name: SHIBBOLETH_IDP_DISCOVERY_URL
  value: {{ .Values.shibd.idp.discovery_url | quote }}
- name: SHIBBOLETH_IDP_ENTITY_ID
  value: {{ .Values.shibd.idp.entity_id | quote }}
- name: SHIBBOLETH_IDP_METADATA_URL
  value: {{ .Values.shibd.idp.metadata_url | quote }}
- name: SHIBBOLETH_SP_ENTITY_ID
  value: {{ .Values.shibd.sp.entity_id | quote }}
- name: SHIBD_ATTRIBUTE_MAP_URL
  value: {{ .Values.shibd.idp.attribute_map_url | quote }}
- name: SHIBD_LISTENER_ACL
  value: {{ .Values.shibd.listener_acl | quote }}
- name: SHIBD_LISTENER_ADDRESS
  value: {{ .Values.shibd.listener_address | quote }}
- name: SHIBD_ODBC_DATABASE
  value: {{ .Values.db.auth.database | quote }}
- name: SHIBD_ODBC_DRIVER
  value: {{ .Values.shibd.odbc.driver | quote }}
- name: SHIBD_ODBC_LIB
  value: {{ .Values.shibd.odbc.lib | quote }}
- name: SHIBD_ODBC_PORT
  value: {{ .Values.db.service.port | quote }}
- name: SHIBD_ODBC_SERVER
  value: {{ template "app.db.fullname" . }}
- name: SHIBD_SERVICE_NAME
  value: {{ template "webwork.fullname" . }}-shibd
- name: SHIBD_SERVICE_PORT
  value: {{ .Values.shibd.service.port | quote }}
- name: SHIB_ODBC_PASSWORD
  valueFrom:
    secretKeyRef:
    {{- if .Values.db.disableExternal }}
      name: {{ template "app.db.fullname" . }}
      key: mariadb-password
    {{- else }}
      name: {{ template "webwork.fullname" . }}
      key: db_password
    {{- end }}
- name: SHIB_ODBC_USER
  value: {{ .Values.db.auth.username | quote }}
- name: SKIP_UPLOAD_OPL_statistics
  value: "true"
- name: MOJO_PUBSUB_EXPERIMENTAL
  value: "1"
volumeMounts:
- name: webwork-course-data
  mountPath: /opt/webwork/courses
- name: webwork-library-data
  mountPath: /opt/webwork/libraries
- name: webwork-htdocs-tmp-data
  mountPath: /opt/webwork/webwork2/htdocs/tmp
- name: webwork-htdocs-data-data
  mountPath: /opt/webwork/webwork2/htdocs/DATA
- name: webwork-logs-data
  mountPath: /opt/webwork/webwork2/logs
  {{- if .Values.webworkFiles }}
- name: localoverrides-config
  mountPath: /opt/webwork/webwork2/conf/localOverrides.conf
  subPath: localOverrides.conf
  {{- end }}
{{- end }}


{{/* webwork container mounts */}}
{{- define "webwork.app.mounts" }}
- name: webwork-course-data
{{- if .Values.coursePersistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ template "webwork.fullname" . }}-course-pvc
{{- else }}
  emptyDir: {}
{{- end }}
- name: webwork-library-data
{{- if .Values.libraryPersistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ template "webwork.fullname" . }}-library-pvc
{{- else }}
  emptyDir: {}
{{- end }}
- name: webwork-htdocs-tmp-data
{{- if .Values.htdocsTmpPersistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ template "webwork.fullname" . }}-htdocs-tmp-pvc
{{- else }}
  emptyDir: {}
{{- end }}
- name: webwork-htdocs-data-data
{{- if .Values.htdocsDataPersistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ template "webwork.fullname" . }}-htdocs-data-pvc
{{- else }}
  emptyDir: {}
{{- end }}
- name: webwork-logs-data
{{- if .Values.logsPersistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ template "webwork.fullname" . }}-logs-pvc
{{- else }}
  emptyDir: {}
{{- end }}
{{- if .Values.webworkFiles }}
- name: localoverrides-config
  configMap:
    name: {{ template "webwork.fullname" . }}
{{- end }}

{{- end }}
