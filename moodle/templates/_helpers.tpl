{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "moodle.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

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
*/}}
{{- define "moodle.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "moodle.db.fullname" -}}
{{- include "call-nested" (list . "db" "mariadb.fullname") -}}
{{- end -}}

{{- define "common_labels" }}
app: {{ template "moodle.fullname" . }}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "moodle.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the proper Moodle image name
*/}}
{{- define "moodle.image" -}}
{{- $registryName := .Values.image.registry -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := .Values.image.tag | toString -}}
{{/*
Helm 2.11 supports the assignment of a value to a variable defined in a different scope,
but Helm 2.9 and 2.10 doesn't support it, so we need to implement this if-else logic.
Also, we can't use a single if because lazy evaluation is not an option
*/}}
{{- if .Values.global }}
    {{- if .Values.global.imageRegistry }}
        {{- printf "%s/%s:%s" .Values.global.imageRegistry $repositoryName $tag -}}
    {{- else -}}
        {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
    {{- end -}}
{{- else -}}
    {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}
{{- end -}}

{{/* Moodle container spec */}}
{{- define "moodle.app.spec" }}
image: '{{ .Values.image.repository }}:{{ .Values.image.tag | default "latest" }}'
imagePullPolicy: {{ default "" .Values.image.pullPolicy | quote }}
env:
- name: SERVER_NAME
  value: https://{{ index .Values.ingress.hosts 0 | default .Values.CI_ENVIRONMENT_HOSTNAME | default "http://localhost" }}:443
- name: MOODLE_DB_TYPE
  value: {{ default "mariadb" .Values.db.db.type | quote }}
- name: MOODLE_DB_HOST
  value: {{ template "moodle.db.fullname" . }}
- name: MOODLE_DB_PORT
  value: {{ .Values.db.service.port | quote }}
- name: MOODLE_DB_USER
  value: {{ default "moodle" .Values.db.db.user | quote }}
- name: MOODLE_DB_PASSWORD
  valueFrom:
    secretKeyRef:
    {{- if .Values.db.disableExternal }}
      name: {{ template "moodle.db.fullname" . }}
      key: mariadb-password
    {{- else }}
      name: {{ template "moodle.fullname" . }}
      key: db_password
    {{- end }}
- name: MOODLE_DB_NAME
  value: {{ .Values.db.db.name | quote }}
{{- if .Values.db.prefix }}
- name: MOODLE_DB_PREFIX
  value: {{ .Values.db.db.prefix | quote }}
{{- end }}
- name: MOODLE_URL
  value: https://{{ index .Values.ingress.hosts 0 | default .Values.CI_ENVIRONMENT_HOSTNAME | default "http://localhost" }}
- name: MOODLE_ADMIN_USER
  value: {{ default "" .Values.moodleUsername | quote }}
- name: MOODLE_ADMIN_PASS
  valueFrom:
    secretKeyRef:
      name: {{ template "moodle.fullname" . }}
      key: moodle_password
- name: MOODLE_ADMIN_EMAIL
  value: {{ default "" .Values.moodleEmail | quote }}
- name: MOODLE_SSL_PROXY
  value: "true"
- name: MOODLE_SITE_FULLNAME
  value: {{ .Values.moodleFullName | quote }}
- name: MOODLE_SITE_SHORTNAME
  value: {{ .Values.moodleShortName | quote }}
- name: MOODLE_SITE_LANG
  value: {{ default "en" .Values.moodleLang | quote }}
- name: SMTP_HOST
  value: {{ default "" .Values.smtpHost | quote }}
- name: SMTP_PORT
  value: {{ default "" .Values.smtpPort | quote }}
- name: SMTP_USER
  value: {{ default "" .Values.smtpUser | quote }}
- name: SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ template "moodle.fullname" . }}
      key: smtp_password
- name: SMTP_PROTOCOL
  value: {{ default "" .Values.smtpProtocol | quote }}
- name: SMTP_AUTH
  value: {{ default "" .Values.smtpAuth | quote }}
- name: MOODLE_NOREPLY_ADDRESS
  value: {{ default "" .Values.moodleNoReplyAddress | quote }}
{{- if .Values.ubcCoursePayment.enabled }}
{{/* Course payment db on same db server as moodle */}}
- name: MOODLE_UBC_COURSE_PAYMENT_DB_HOST
  value: {{ template "moodle.db.fullname" . }}
- name: MOODLE_UBC_COURSE_PAYMENT_DB_NAME
  value: {{ default "" .Values.ubcCoursePayment.db.name | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_DB_USER
  value: {{ default "moodle" .Values.db.db.user | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_DB_PASSWORD
  valueFrom:
    secretKeyRef:
    {{- if .Values.db.disableExternal }}
      name: {{ template "moodle.db.fullname" . }}
      key: mariadb-password
    {{- else }}
      name: {{ template "moodle.fullname" . }}
      key: db_password
    {{- end }}
- name: MOODLE_UBC_COURSE_PAYMENT_DB_PORT
  value: {{ .Values.db.service.port | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_UPLOAD_DIR
  value: {{ default "" .Values.ubcCoursePayment.uploadDir | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_CBM_DEBUG
  value: {{ default "false" .Values.ubcCoursePayment.cbm.debug | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_CBM_LOGFILE
  value: {{ default "" .Values.ubcCoursePayment.cbm.logfile | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_CBM_AUTH_URL
  value: {{ default "" .Values.ubcCoursePayment.cbm.authUrl | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_CBM_PYMT_URL
  value: {{ default "" .Values.ubcCoursePayment.cbm.pymtUrl | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_CBM_USER_ID
  value: {{ default "" .Values.ubcCoursePayment.cbm.userId | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_CBM_CREDENTIAL
  value: {{ default "" .Values.ubcCoursePayment.cbm.credential | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_CBM_SRCE_TYP_CD
  value: {{ default "" .Values.ubcCoursePayment.cbm.srceTypCd | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_EMAIL_FROM
  value: {{ default "" .Values.ubcCoursePayment.email.from | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_EMAIL_RMS_RECIPIENT
  value: {{ default "" .Values.ubcCoursePayment.email.rmsRecipient | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_EMAIL_IMMUNIZATION
  value: {{ default "" .Values.ubcCoursePayment.email.immunization | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_EMAIL_IMMUNIZATION_RECIPIENT
  value: {{ default "" .Values.ubcCoursePayment.email.immunizationRecipient | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_EMAIL_JV_RECIPIENT
  value: {{ default "" .Values.ubcCoursePayment.email.jvRecipient | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_EMAIL_JCART_JV_RECIPIENT
  value: {{ default "" .Values.ubcCoursePayment.email.jcartJvRecipient | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_EMAIL_WEBSITE_ADMIN
  value: {{ default "" .Values.ubcCoursePayment.email.websiteAdmin | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_FIT_TEST_MOODLE_COURSE_ID
  value: {{ default "" .Values.ubcCoursePayment.fitTest.moodleCourseId | quote }}
{{- end }}
- name: UPLOAD_MAX_FILESIZE
  value: {{ .Values.uploadMaxFileSize | quote }}
{{- if .Values.redis.enabled }}
- name: REDIS_HOST
  value: {{ template "moodle.fullname" . }}-redis
- name: REDIS_PORT
  value: "6379"
- name: REDIS_DB
  value: {{ default 0 .Values.redis.db | quote }}
- name: REDIS_PREFIX
  value: {{ default "" .Values.redis.prefix | quote }}
{{- end }}
{{- if .Values.debug }}
- name: MOODLE_DEBUG
  value: "true"
{{- end }}
{{- if .Values.shib.enabled }}
- name: SHIBBOLETH_IDP_DISCOVERY_URL
  value: {{ .Values.shib.idp.discoveryUrl }}
- name: SHIBBOLETH_IDP_METADATA_URL
  value: {{ .Values.shib.idp.metadataUrl }}
- name: SHIBBOLETH_IDP_ENTITY_ID
  value: {{ .Values.shib.idp.entityId }}
- name: SHIBD_ATTRIBUTE_MAP_URL
  value: {{ .Values.shib.idp.attributeMapUrl }}
- name: SHIBBOLETH_SP_ENTITY_ID
  value: {{ .Values.shib.sp.entityId }}
- name: SHIBD_LISTENER_ACL
  value: "0.0.0.0/0"
- name: SHIBD_ODBC_DRIVER
  value: {{ .Values.shib.odbc.driver }}
- name: SHIBD_ODBC_LIB
  value: {{ .Values.shib.odbc.lib }}
- name: SHIBD_ODBC_SERVER
  value: {{ template "moodle.db.fullname" . | default .Values.db.service.name }}
- name: SHIBD_ODBC_PORT
  value: {{ .Values.db.service.port | quote }}
- name: SHIBD_ODBC_DATABASE
  value: {{ .Values.db.db.name | quote }}
- name: SHIB_ODBC_USER
  value: {{ default "moodle" .Values.db.db.user | quote }}
- name: SHIB_ODBC_PASSWORD
  valueFrom:
    secretKeyRef:
    {{- if .Values.db.disableExternal }}
      name: {{ template "moodle.db.fullname" . }}
      key: mariadb-password
    {{- else }}
      name: {{ template "moodle.fullname" . }}
      key: db_password
    {{- end }}
- name: SHIBD_SERVICE_NAME
  value: {{ template "moodle.fullname" . }}-shibd
- name: SHIBD_SERVICE_PORT
  value: {{ .Values.shib.port | quote }}
{{- end }}
- name: PHP_MEMORY_LIMIT
  value: {{ .Values.phpMemoryLimit | quote }}
- name: PHP_MAX_EXECUTION_TIME
  value: {{ .Values.phpMaxExecutionTime | quote }}
volumeMounts:
- name: moodle-data
  mountPath: /moodledata
{{- end }}


{{/* Moodle container mounts */}}
{{- define "moodle.app.mounts" }}
- name: moodle-data
{{- if .Values.persistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ template "moodle.fullname" . }}-app-pvc
{{- else }}
  emptyDir: {}
{{- end }}
{{- end }}

{{/*
Return the proper image name (for the metrics image)
*/}}
{{- define "moodle.metrics.image" -}}
{{- $registryName := .Values.metrics.image.registry -}}
{{- $repositoryName := .Values.metrics.image.repository -}}
{{- $tag := .Values.metrics.image.tag | toString -}}
{{/*
Helm 2.11 supports the assignment of a value to a variable defined in a different scope,
but Helm 2.9 and 2.10 doesn't support it, so we need to implement this if-else logic.
Also, we can't use a single if because lazy evaluation is not an option
*/}}
{{- if .Values.global }}
    {{- if .Values.global.imageRegistry }}
        {{- printf "%s/%s:%s" .Values.global.imageRegistry $repositoryName $tag -}}
    {{- else -}}
        {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
    {{- end -}}
{{- else -}}
    {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "moodle.imagePullSecrets" -}}
{{/*
Helm 2.11 supports the assignment of a value to a variable defined in a different scope,
but Helm 2.9 and 2.10 does not support it, so we need to implement this if-else logic.
Also, we can not use a single if because lazy evaluation is not an option
*/}}
{{- if .Values.global }}
{{- if .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.global.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- else if or .Values.image.pullSecrets .Values.metrics.image.pullSecrets }}
imagePullSecrets:
{{- range .Values.image.pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- range .Values.metrics.image.pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- else if or .Values.image.pullSecrets .Values.metrics.image.pullSecrets }}
imagePullSecrets:
{{- range .Values.image.pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- range .Values.metrics.image.pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}
