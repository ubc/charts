{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "moodle.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

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
*/}}
{{- define "moodle.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*{{ define "moodle.fullname" -}}*/}}
{{/*{{- if .Values.fullnameOverride }}*/}}
{{/*{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}*/}}
{{/*{{- else }}*/}}
{{/*{{- $name := default .Chart.Name .Values.nameOverride }}*/}}
{{/*{{- if contains $name .Release.Name }}*/}}
{{/*{{- .Release.Name | trunc 63 | trimSuffix "-" }}*/}}
{{/*{{- else }}*/}}
{{/*{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}*/}}
{{/*{{- end }}*/}}
{{/*{{- end }}*/}}
{{/*{{- end }}*/}}

{{/*
Create a default fully qualified app name for the database.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "moodle.db.fullname" -}}
{{- include "call-nested" (list . "db" "mariadb.fullname") -}}
{{- end -}}

{{- define "moodle.secretname" -}}
{{- if .Values.moodleExistingSecret }}
{{- .Values.moodleExistingSecret -}}
{{- else -}}
{{ include "moodle.fullname" . }}
{{- end -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "moodle.labels" -}}
helm.sh/chart: {{ include "moodle.chart" . }}
{{ include "moodle.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "moodle.selectorLabels" -}}
app.kubernetes.io/name: {{ include "moodle.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
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
image: '{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}'
imagePullPolicy: {{ default "" .Values.image.pullPolicy | quote }}
env:
- name: SERVER_NAME
  value: https://{{ index .Values.ingress.hosts 0 | default .Values.CI_ENVIRONMENT_HOSTNAME | default "http://localhost" }}:443
- name: MOODLE_DB_TYPE
  value: {{ default "mariadb" .Values.db.db.type | quote }}
- name: MOODLE_DB_HOST
  value: {{ include "moodle.databaseHost" .}}
- name: MOODLE_DB_PORT
  value: {{ include "moodle.databasePort" . }}
- name: MOODLE_DB_USER
  value: {{ include "moodle.databaseUser" .}}
- name: MOODLE_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "moodle.databaseSecretName" . }}
      key: {{ include "moodle.databaseSecretKey" . }}
- name: MOODLE_DB_NAME
  value: {{ include "moodle.databaseName" .}}
{{- if .Values.db.db.prefix }}
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
      name: {{ template "moodle.secretname" . }}
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
      name: {{ template "moodle.secretname" . }}
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
  value: {{ include "moodle.databaseHost" .}}
- name: MOODLE_UBC_COURSE_PAYMENT_DB_NAME
  value: {{ default "" .Values.ubcCoursePayment.db.name | quote }}
- name: MOODLE_UBC_COURSE_PAYMENT_DB_USER
  value: {{ include "moodle.databaseUser" .}}
- name: MOODLE_UBC_COURSE_PAYMENT_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "moodle.databaseSecretName" . }}
      key: {{ include "moodle.databaseSecretKey" . }}
- name: MOODLE_UBC_COURSE_PAYMENT_DB_PORT
  value: {{ include "moodle.databasePort" . }}
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
  value: {{ include "moodle.fullname" . }}-redis
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
  value: {{ include "moodle.databaseHost" .}}
- name: SHIBD_ODBC_PORT
  value: {{ include "moodle.databasePort" . }}
- name: SHIBD_ODBC_DATABASE
  value: {{ include "moodle.databaseName" .}}
- name: SHIB_ODBC_USER
  value: {{ include "moodle.databaseUser" .}}
- name: SHIB_ODBC_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "moodle.databaseSecretName" . }}
      key: {{ include "moodle.databaseSecretKey" . }}
- name: SHIBD_SERVICE_NAME
  value: {{ include "moodle.fullname" . }}-shibd
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
    claimName: {{ include "moodle.fullname" . }}-app-pvc
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
{{- include "common.images.renderPullSecrets" (dict "images" (list .Values.image .Values.memcached.image .Values.redis.image .Values.shib.image) "context" $) -}}
{{- end }}

{{/*
Return the proper Docker Image Registry Secret Names evaluating values as templates
{{ include "common.images.renderPullSecrets" ( dict "images" (list .Values.path.to.the.image1, .Values.path.to.the.image2) "context" $) }}
*/}}
{{- define "common.images.renderPullSecrets" -}}
  {{- $pullSecrets := list }}
  {{- $context := .context }}

  {{- range (($context.Values.global).imagePullSecrets) -}}
    {{- if kindIs "map" . -}}
      {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" .name "context" $context)) -}}
    {{- else -}}
      {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" . "context" $context)) -}}
    {{- end -}}
  {{- end -}}

  {{- range .images -}}
    {{- range .pullSecrets -}}
      {{- if kindIs "map" . -}}
        {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" .name "context" $context)) -}}
      {{- else -}}
        {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" . "context" $context)) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- if (not (empty $pullSecrets)) -}}
imagePullSecrets:
    {{- range $pullSecrets | uniq }}
  - name: {{ . }}
    {{- end }}
  {{- end }}
{{- end -}}


{{/*
Return the MariaDB Hostname
*/}}
{{- define "moodle.databaseHost" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.architecture "replication" }}
        {{- printf "%s-primary" (include "moodle.db.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- printf "%s" (include "moodle.db.fullname" .) -}}
    {{- end -}}
{{- else -}}
    {{- printf "%s" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Port
*/}}
{{- define "moodle.databasePort" -}}
{{- if .Values.db.enabled }}
    {{- printf "3306" | quote -}}
{{- else -}}
    {{- printf "%d" (.Values.externalDatabase.port | int ) -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Database Name
*/}}
{{- define "moodle.databaseName" -}}
{{- if .Values.db.enabled }}
    {{- printf "%s" .Values.db.auth.database -}}
{{- else -}}
    {{- printf "%s" .Values.externalDatabase.database -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB User
*/}}
{{- define "moodle.databaseUser" -}}
{{- if .Values.db.enabled }}
    {{- printf "%s" .Values.db.auth.username -}}
{{- else -}}
    {{- printf "%s" .Values.externalDatabase.user -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Secret Name
*/}}
{{- define "moodle.databaseSecretName" -}}
{{- if .Values.db.enabled }}
    {{- if and .Values.db.auth.existingSecret .Values.db.auth.userPasswordKey -}}
        {{- printf "%s" .Values.db.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s-user-password" (include "moodle.db.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
    {{- tpl .Values.externalDatabase.existingSecret $ -}}
{{- else -}}
    {{- printf "%s-externaldb" (include "moodle.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Secret Key
*/}}
{{- define "moodle.databaseSecretKey" -}}
{{- if .Values.db.enabled }}
    {{- if and .Values.db.auth.existingSecret .Values.db.auth.userPasswordKey -}}
        {{- printf "%s" .Values.db.auth.userPasswordKey -}}
    {{- else -}}
        {{- printf "password-%s" (include "moodle.databaseUser" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
    {{- tpl .Values.externalDatabase.existingSecret $ -}}
{{- else -}}
    {{- printf "%s-externaldb" (include "moodle.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Root Secret Name
*/}}
{{- define "moodle.databaseRootSecretName" -}}
{{- if .Values.db.enabled }}
    {{- if and .Values.db.auth.existingSecret .Values.db.auth.rootPasswordKey -}}
        {{- printf "%s" .Values.db.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s-root" (include "moodle.db.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
    {{- tpl .Values.externalDatabase.existingSecret $ -}}
{{- else -}}
    {{- printf "%s-externaldb" (include "moodle.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the MariaDB Root Secret Key
*/}}
{{- define "moodle.databaseRootSecretKey" -}}
{{- if .Values.db.enabled }}
    {{- if and .Values.db.auth.existingSecret .Values.db.auth.rootPasswordKey -}}
        {{- printf "%s" .Values.db.auth.rootPasswordKey -}}
    {{- else -}}
        {{- printf "password" -}}
    {{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
    {{- tpl .Values.externalDatabase.existingSecret $ -}}
{{- else -}}
    {{- printf "%s-externaldb" (include "moodle.fullname" .) -}}
{{- end -}}
{{- end -}}
