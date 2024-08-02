{{/*
Expand the name of the chart.
*/}}
{{- define "mediawiki.name" -}}
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
{{- define "mediawiki.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "mediawiki.db.fullname" -}}
{{- $name := printf "%s-%s" .Release.Name "db" -}}
{{- default $name .Values.db.service.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "common_labels" }}
app: {{ template "mediawiki.fullname" . }}
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

{{/* SimpleSAMLphp container spec */}}

{{- define "simplesamlphp.domain" -}}
{{- index .Values.ingress.hosts 0 | default .Values.CI_ENVIRONMENT_HOSTNAME | default "localhost" -}}
{{- end -}}
{{- define "simplesamlphp.baseurl" -}}
https://{{ template "simplesamlphp.domain" . }}
{{- end -}}
{{- define "simplesamlphp.baseurlpath" -}}
{{ template "simplesamlphp.baseurl" . }}/_saml2/
{{- end -}}

{{- define "simplesamlphp.app.spec.env" }}
- name: SIMPLESAMLPHP_SECRET_SALT
  value: {{ .Values.simplesamlphp.secretSalt | quote }}
- name: SIMPLESAMLPHP_ADMIN_PASSWORD
  value: {{ .Values.simplesamlphp.adminPassword | quote }}
- name: SIMPLESAMLPHP_CRON_SECRET
  value: {{ .Values.simplesamlphp.cronSecret | quote }}
- name: SIMPLESAMLPHP_MEMCACHED_SERVER
  value: {{ template "mediawiki.fullname" . }}-memcached
- name: SIMPLESAMLPHP_TRUSTED_DOMAIN
  value: {{ template "simplesamlphp.domain" . }}
- name: SIMPLESAMLPHP_BASEURL
  value: {{ template "simplesamlphp.baseurl" . }}
- name: SIMPLESAMLPHP_BASEURLPATH
  value: {{ template "simplesamlphp.baseurlpath" . }}
- name: SIMPLESAMLPHP_SP_ENTITY_ID
  value: {{ .Values.simplesamlphp.sp.entityId | quote }}
- name: SIMPLESAMLPHP_IDP_ENTITY_ID
  value: {{ .Values.simplesamlphp.idp.entityId | quote }}
- name: SIMPLESAMLPHP_IDP_METADATA_URL
  value: {{ .Values.simplesamlphp.idp.metadataUrl | quote }}
{{- if .Values.simplesamlphp.enabled }}
- name: SIMPLESAMLPHP_ENABLED
  value: "1"
{{- end }}
{{- if .Values.simplesamlphp.dev }}
- name: SIMPLESAMLPHP_DEV
  value: "1"
{{- end }}
{{- end }}

{{/* Mediawiki container spec */}}
{{- define "mediawiki.app.spec" }}
image: '{{ .Values.image.repository }}:{{ .Values.image.tag | default "latest" }}'
imagePullPolicy: {{ default "" .Values.imagePullPolicy | quote }}
env:
- name: MEDIAWIKI_DB_HOST
  value: {{ template "mediawiki.db.fullname" . | default .Values.db.service.name }}
- name: MEDIAWIKI_DB_PORT
  value: {{ .Values.db.service.port | quote }}
- name: MEDIAWIKI_DB_USER
  value: {{ default "wiki" .Values.db.auth.username | quote }}
- name: MEDIAWIKI_DB_PASSWORD
  valueFrom:
    secretKeyRef:
    {{- if .Values.db.disableExternal }}
      name: {{ include "call-nested" (list . "db" "common.names.fullname") }}
      key: mariadb-password
    {{- else }}
      name: {{ template "mediawiki.fullname" . }}
      key: db_password
    {{- end }}
- name: MEDIAWIKI_DB_NAME
  value: {{ .Values.db.auth.database | quote }}
- name: MEDIAWIKI_DB_SCHEMA
  value: {{ .Values.db.auth.schema | quote }}
- name: MEDIAWIKI_ADMIN_USER
  value: {{ default "" .Values.adminUser | quote }}
- name: MEDIAWIKI_ADMIN_PASS
  valueFrom:
    secretKeyRef:
      name: {{ template "mediawiki.fullname" . }}
      key: mediawiki_password
- name: MEDIAWIKI_EMAIL
  value: {{ default "" .Values.mediawikiEmail | quote }}
{{- if .Values.mediawikiEmergencyContact }}
- name: MEDIAWIKI_EMERGENCY_CONTACT
  value:  {{ .Values.mediawikiEmergencyContact | quote }}
{{- end }}
{{- if .Values.mediawikiPasswordSender }}
- name: MEDIAWIKI_PASSWORD_SENDER
  value:  {{ .Values.mediawikiPasswordSender | quote }}
{{- end }}
- name: MEDIAWIKI_SITE_SERVER
  value: https://{{ index .Values.ingress.hosts 0 | default .Values.CI_ENVIRONMENT_HOSTNAME | default "http://localhost" }}
- name: MEDIAWIKI_SITE_NAME
  value: {{ .Values.mediawikiName | quote }}
- name: MEDIAWIKI_SITE_LANG
  value: {{ .Values.mediawikiLang | quote }}
{{- if .Values.mediawikiLogo }}
- name: MEDIAWIKI_LOGO_ICON
  value: {{ .Values.mediawikiLogo.icon | quote }}
{{- if .Values.mediawikiLogo.legacy1x }}
- name: MEDIAWIKI_LOGO_LEGACY1X
  value: {{ .Values.mediawikiLogo.legacy1x | quote }}
{{- end }}
{{- if .Values.mediawikiLogo.legacy2x }}
- name: MEDIAWIKI_LOGO_LEGACY2X
  value: {{ .Values.mediawikiLogo.legacy2x | quote }}
{{- end }}
{{- end }}
{{- if .Values.mediawikiUploadPath  }}
- name: MEDIAWIKI_UPLOAD_PATH
  value: {{ .Values.mediawikiUploadPath | quote }}
{{- end }}
- name: MEDIAWIKI_EXTENSIONS
  value: {{ .Values.mediawikiExts | quote }}
{{- if .Values.mediawikiAllowSiteCSSOnRestrictedPages }}
- name: MEDIAWIKI_ALLOW_SITE_CSS_ON_RESTRICTED_PAGES
  value: {{ .Values.mediawikiAllowSiteCSSOnRestrictedPages | quote }}
{{- end }}
{{- if .Values.mediawikiAllowAnonymousEdit}}
- name: MEDIAWIKI_ALLOW_ANONYMOUS_EDIT
  value: {{ .Values.mediawikiAllowAnonymousEdit | quote }}
{{- end }}
- name: MEDIAWIKI_ENABLE_BOT_PASSWORDS
  value: {{ .Values.mediawikiEnableBotPasswords | quote }}
- name: SMTP_HOST_ID
  value: {{ default "" .Values.smtpHostID | quote }}
- name: SMTP_HOST
  value: {{ default "" .Values.smtpHost | quote }}
- name: SMTP_PORT
  value: {{ default "" .Values.smtpPort | quote }}
- name: SMTP_USER
  value: {{ default "" .Values.smtpUser | quote }}
- name: SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ template "mediawiki.fullname" . }}
      key: smtp_password
{{- if .Values.node_services.enabled }}
- name: PARSOID_URL
  value: http://{{ template "mediawiki.fullname" . }}-parsoid:8142
- name: PARSOID_DOMAIN
  value: localhost
- name: RESTBASE_URL
  value: http://{{ template "mediawiki.fullname" . }}-restbase:7231
{{- end }}
{{- if .Values.ldap.enabled }}
- name: LDAP_DOMAIN
  value: {{ .Values.ldap.domain }}
- name: LDAP_SERVER
  value: {{ .Values.ldap.server }}
- name: LDAP_PORT
  value: {{ .Values.ldap.port | quote }}
- name: LDAP_BASE_DN
  value: {{ .Values.ldap.baseDn }}
{{- if .Values.ldap.searchStrings }}
- name: LDAP_SEARCH_STRINGS
  value: {{ .Values.ldap.searchStrings }}
{{- end }}
{{- if .Values.ldap.searchAttrs }}
- name: LDAP_SEARCH_ATTRS
  value: {{ .Values.ldap.searchAttrs }}
{{- end }}
{{- if .Values.ldap.proxyAgent }}
- name: LDAP_PROXY_AGENT
  value: {{ .Values.ldap.proxyAgent }}
{{- end }}
{{- if .Values.ldap.proxyPassword }}
- name: LDAP_PROXY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ template "mediawiki.fullname" . }}
      key: ldap_proxy_password
{{- end }}
{{- if .Values.ldap.userBaseDn }}
- name: LDAP_USER_BASE_DN
  value: {{ .Values.ldap.userBaseDn }}
{{- end }}
{{- if .Values.ldap.usernameAttr }}
- name: LDAP_USERNAME_ATTR
  value: {{ .Values.ldap.usernameAttr }}
{{- end }}
{{- if .Values.ldap.realnameAttr }}
- name: LDAP_REALNAME_ATTR
  value: {{ .Values.ldap.realnameAttr }}
{{- end }}
{{- if .Values.ldap.emailAttr }}
- name: LDAP_EMAIL_ATTR
  value: {{ .Values.ldap.emailAttr }}
{{- end }}
- name: LDAP_ENCRYPTION_TYPE
  value: {{ .Values.ldap.encryption }}
{{- if .Values.ldap.ubcAuthEnabled }}
- name: UBC_AUTH_ENABLED
  value: {{ .Values.ldap.ubcAuthEnabled | quote }}
{{- end }}
{{- if .Values.parsoid.skipDomainCheck }}
- name: PARSOID_SKIP_DOAMIN_CHECK
  value: {{ .Values.parsoid.skipDomainCheck | quote }}
{{- end }}
{{- if .Values.mediawikiUserRedirect.created }}
- name: AUTO_CREATED_USER_REDIRECT
  value: {{ .Values.mediawikiUserRedirect.created }}
{{- end }}
{{- if .Values.mediawikiUserRedirect.blocked }}
- name: AUTO_BLOCKED_USER_REDIRECT
  value: {{ .Values.mediawikiUserRedirect.blocked }}
{{- end }}
{{- end }}
- name: MEDIAWIKI_MAIN_CACHE
  value: {{ .Values.mainCache }}
{{- if .Values.memcached.enabled }}
- name: MEDIAWIKI_MEMCACHED_SERVERS
  value: '["{{ template "mediawiki.fullname" . }}-memcached:11211"]'
{{- end }}
{{- if .Values.redis.enabled }}
- name: MEDIAWIKI_REDIS_HOST
  value: {{ .Values.redis.host | quote }}
- name: MEDIAWIKI_REDIS_PORT
  value: {{ .Values.redis.port | quote }}
  {{- if .Values.redis.password }}
- name: MEDIAWIKI_REDIS_PASSWORD
  value: {{ .Values.redis.password | quote }}
  {{- end  }}
- name: MEDIAWIKI_REDIS_PERSISTENT
  value: {{ .Values.redis.persistent | quote }}
{{- end }}
{{- if .Values.caliper.enabled }}
- name: CALIPER_HOST
  value: {{ .Values.caliper.host | quote }}
{{- if .Values.caliper.api_key }}
- name: CALIPER_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ template "mediawiki.fullname" . }}
      key: caliper_api_key
{{- end  }}
- name: CALIPER_BASE_URL
  value: {{ .Values.caliper.app_base_url | quote }}
- name: CALIPER_LDAP_ACTOR_HOMEPAGE
  value: {{ .Values.caliper.ldap_actor_homepage | quote }}
{{- end }}
{{- if .Values.debug }}
- name: DEBUG
  value: {{ .Values.debug | quote }}
{{- end }}

{{- if .Values.cacheDirectory }}
- name: MEDIAWIKI_CACHE_DIRECTORY
  value: {{ .Values.cacheDirectory }}
{{- end }}
{{- if .Values.l10nCacheStore }}
- name: MEDIAWIKI_LOCALISATION_CACHE_STORE
  value: {{ .Values.l10nCacheStore }}
{{- end }}
{{- if .Values.l10nCacheManualRecache }}
- name: MEDIAWIKI_LOCALISATION_CACHE_MANUALRECACHE
  value: {{ .Values.l10nCacheManualRecache | quote }}
{{- end }}
{{- if .Values.googleAnalytics.id }}
- name: GOOGLE_ANALYTICS_ID
  value: {{ .Values.googleAnalytics.id | quote }}
{{- end }}
{{- if .Values.googleAnalytics.metricsAllowed }}
- name: GOOGLE_ANALYTICS_METRICS_ALLOWED
  value: {{ .Values.googleAnalytics.metricsAllowed | quote }}
{{- end }}
{{- if .Values.googleAnalytics.metricsPath }}
- name: GOOGLE_ANALYTICS_METRICS_PATH
  value: {{ .Values.googleAnalytics.metricsPath | quote }}
{{- end }}
{{- if .Values.googleAnalytics.metricsViewID }}
- name: GOOGLE_ANALYTICS_METRICS_VIEWID
  value: {{ .Values.googleAnalytics.metricsViewID | quote }}
{{- end }}
{{- if .Values.googleMap.apiKey }}
- name: GOOGLE_MAP_API_KEY
  value: {{ .Values.googleMap.apiKey | quote }}
{{- end }}
{{- if .Values.simplesamlphp.enabled }}
{{- include "simplesamlphp.app.spec.env" . }}
{{- end }}
volumeMounts:
- name: mediawiki-data
  mountPath: /data
- name: custom-config
  mountPath: /conf
{{- if .Values.simplesamlphp.enabled }}
- name: simplesamlphp-code
  mountPath: /var/www/simplesamlphp
  readOnly: true
{{- end }}
{{- end }}


{{/* Mediawiki container mounts */}}
{{- define "mediawiki.app.mounts" }}
- name: mediawiki-data
{{- if .Values.persistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ template "mediawiki.fullname" . }}-app-pvc
{{- else }}
  emptyDir: {}
{{- end }}
- name: custom-config
  configMap:
    name: {{ template "mediawiki.fullname" . }}
{{- if .Values.simplesamlphp.enabled }}
- name: simplesamlphp-code
  persistentVolumeClaim:
    claimName: {{ template "mediawiki.fullname" . }}-simplesamlphp-pvc
{{- end }}
{{- end }}
