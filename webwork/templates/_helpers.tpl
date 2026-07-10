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

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "app.db.fullname" -}}
{{- if .Values.db.enabled -}}
{{- if eq .Values.db.architecture "replication" -}}
{{- printf "%s-primary" (include "call-nested" (list . "db" "mariadb.fullname")) | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "call-nested" (list . "db" "mariadb.fullname") | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- else -}}
{{- if .Values.db.service.name -}}
{{- printf "%s" .Values.db.service.name -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "db" -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{/*
Command prefix that drops privileges to the unprivileged web-server user.

The container starts as root so it can `sudo -u www-data` (drop privileges);
the long-running app process runs as www-data (uid 33) — matching the web pod's
hypnotoad — so every WeBWorK process runs as the same user. `-E` preserves the
environment (DB creds, WW_* secrets) across the privilege drop.

EFS ownership: the writable access points (courses, htdocs/tmp, htdocs/DATA,
logs) enforce PosixUser uid=33/gid=33, so every file is born owned by www-data
and is directly writable by the app — no dependency on group-write bits or on
the entrypoint's "Fixing ownership and permissions" pass (which is now best-
effort / a no-op, since root-in-pod is squashed to uid 33 on those mounts). The
library access point stays uid=0/gid=33: it's the read-only OPL, consumed via
the world-read bit, and keeps OPL-update (root) able to write it.

Renders as inline JSON-array elements with a trailing comma, e.g.
  args: [{{ include "webwork.dropPrivPrefix" . }} 'bin/webwork2', 'minion', 'worker']
*/}}
{{- define "webwork.dropPrivPrefix" -}}
'sudo', '-E', '-u', {{ .Values.appUser | default "www-data" | squote }},
{{- end -}}


{{/* webwork container spec */}}
{{- define "webwork.app.spec" }}
securityContext:
  {{- toYaml .Values.securityContext | nindent 12 }}
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
imagePullPolicy: {{ .Values.image.pullPolicy }}
{{- if .Values.externalSecrets.enabled }}
envFrom:
- secretRef:
    name: {{ .Values.externalSecrets.secretName }}
{{- end }}
env:
- name: WEBWORK_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ if .Values.externalSecrets.enabled }}{{ .Values.externalSecrets.secretName }}{{ else }}{{ include "webwork.fullname" . }}{{ end }}
      key: webwork_secret
- name: WEBWORK_DB_DRIVER
  value: {{ .Values.db.db.driver | quote }}
- name: WEBWORK_DB_HOST
{{- if eq (include "webwork.db.provider" .) "ack" }}
  valueFrom:
    configMapKeyRef:
      name: {{ printf "%s-rds-endpoint" (include "webwork.fullname" .) }}
      key: endpoint
{{- else }}
  value: {{ template "app.db.fullname" . }}
{{- end }}
- name: WEBWORK_DB_PORT
{{- if eq (include "webwork.db.provider" .) "ack" }}
  valueFrom:
    configMapKeyRef:
      name: {{ printf "%s-rds-endpoint" (include "webwork.fullname" .) }}
      key: port
{{- else }}
  value: {{ .Values.db.service.port | quote }}
{{- end }}
- name: WEBWORK_DB_NAME
  value: {{ .Values.db.auth.database | quote }}
- name: WEBWORK_DB_USER
  value: {{ .Values.db.auth.username | quote }}
- name: WEBWORK_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- include "webwork.db.passwordSecretRef" . | nindent 6 }}
- name: WEBWORK_ROOT_URL
  value: {{ .Values.rootUrl | quote }}
- name: WEBWORK_TIMEZONE
  value: {{ .Values.timezone | quote }}
- name: WEBWORK_SUPPORT_EMAIL
  value: {{ .Values.supportEmail | quote }}
- name: R_HOST
  value: {{ template "webwork.fullname" . }}-r
- name: SYSTEM_TIMEZONE
  value: {{ .Values.systemTimezone | quote }}
- name: WEBWORK_SMTP_SERVER
  value: {{ .Values.smtp.server | quote }}
- name: WEBWORK_SMTP_SENDER
  value: {{ .Values.smtp.sender | quote }}
- name: SKIP_UPLOAD_OPL_statistics
  value: "true"
- name: MAX_REQUEST_SIZE
  value: {{ .Values.maxRequestSize | quote }}
- name: MOJO_PUBSUB_EXPERIMENTAL
  value: "1"
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
{{- if eq (include "webwork.db.provider" .) "ack" }}
  valueFrom:
    configMapKeyRef:
      name: {{ printf "%s-rds-endpoint" (include "webwork.fullname" .) }}
      key: port
{{- else }}
  value: {{ .Values.db.service.port | quote }}
{{- end }}
- name: SHIBD_ODBC_SERVER
{{- if eq (include "webwork.db.provider" .) "ack" }}
  valueFrom:
    configMapKeyRef:
      name: {{ printf "%s-rds-endpoint" (include "webwork.fullname" .) }}
      key: endpoint
{{- else }}
  value: {{ template "app.db.fullname" . }}
{{- end }}
- name: SHIBD_SERVICE_NAME
  value: {{ template "webwork.fullname" . }}-shibd
- name: SHIBD_SERVICE_PORT
  value: {{ .Values.shibd.service.port | quote }}
- name: SHIB_ODBC_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- include "webwork.db.passwordSecretRef" . | nindent 6 }}
- name: SHIB_ODBC_USER
  value: {{ .Values.db.auth.username | quote }}
{{- with .Values.extraEnv }}
{{ toYaml . }}
{{- end }}
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
  {{- if (.Values.webworkFiles).localOverrides }}
- name: localoverrides-config
  mountPath: /opt/webwork/webwork2/conf/localOverrides.conf
  subPath: localOverrides.conf
  {{- end }}
  {{- if or (.Values.webworkFiles).authen_saml2 .Values.externalSecrets.saml2SecretName }}
- name: authen-saml2-config
  mountPath: /opt/webwork/webwork2/conf/authen_saml2.yml
  subPath: authen_saml2.yml
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
{{- else if .Values.logShipping.enabled }}
  emptyDir:
    sizeLimit: {{ .Values.logShipping.emptyDirSizeLimit }}
{{- else }}
  emptyDir: {}
{{- end }}
{{- if (.Values.webworkFiles).localOverrides }}
- name: localoverrides-config
  configMap:
    name: {{ template "webwork.fullname" . }}
    items:
    - key: localOverrides
      path: localOverrides.conf
{{- end }}
{{- if .Values.externalSecrets.saml2SecretName }}
- name: authen-saml2-config
  secret:
    secretName: {{ .Values.externalSecrets.saml2SecretName }}
    items:
    - key: authen_saml2.yml
      path: authen_saml2.yml
{{- else if (.Values.webworkFiles).authen_saml2 }}
- name: authen-saml2-config
  configMap:
    name: {{ template "webwork.fullname" . }}
    items:
    - key: authen_saml2
      path: authen_saml2.yml
{{- end }}
{{- if .Values.logShipping.enabled }}
{{- include "webwork.logShipper.volumes" . | nindent 0 }}
{{- end }}

{{- end }}

{{/*
Log-shipping native sidecars.

Rendered into each workload's `initContainers:` as native sidecars
(restartPolicy: Always) — they start before the app and keep running, but
terminate when the main container exits, so cronjob Jobs still complete. Gated by
the caller on .Values.logShipping.enabled.

  - log-shipper: Fluent Bit tails /opt/webwork/webwork2/logs/*.log (read-only)
    and HTTP-POSTs to the on-prem relay (basicAuth from the synced secret).
  - log-rotate (optional): truncates any *.log over maxBytes; truncate-in-place is
    safe with WeBWorK's O_APPEND writers and Fluent Bit tail (which re-reads from 0).
*/}}
{{- define "webwork.logShipper.initContainers" -}}
- name: log-shipper
  image: "{{ .Values.logShipping.image.repository }}:{{ .Values.logShipping.image.tag }}"
  imagePullPolicy: {{ .Values.logShipping.image.pullPolicy }}
  restartPolicy: Always
  args: ["-c", "/fluent-bit/etc/fluent-bit.conf"]
  env:
    - name: LOGRELAY_USER
      valueFrom:
        secretKeyRef:
          name: {{ .Values.logShipping.auth.secretName }}
          key: username
    - name: LOGRELAY_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ .Values.logShipping.auth.secretName }}
          key: password
  volumeMounts:
    - name: webwork-logs-data
      mountPath: /opt/webwork/webwork2/logs
      readOnly: true
    - name: log-shipper-config
      mountPath: /fluent-bit/etc
    - name: log-shipper-buffer
      mountPath: /var/log/fluent-bit
  resources:
    {{- toYaml .Values.logShipping.resources | nindent 4 }}
{{- if .Values.logShipping.rotation.enabled }}
- name: log-rotate
  image: "{{ .Values.logShipping.rotation.image.repository }}:{{ .Values.logShipping.rotation.image.tag }}"
  imagePullPolicy: {{ .Values.logShipping.rotation.image.pullPolicy }}
  restartPolicy: Always
  command:
    - /bin/sh
    - -c
    - |
      MAX={{ .Values.logShipping.rotation.maxBytes }}
      while true; do
        for f in /opt/webwork/webwork2/logs/*.log; do
          [ -f "$f" ] || continue
          sz=$(wc -c < "$f" 2>/dev/null || echo 0)
          [ "$sz" -gt "$MAX" ] && : > "$f"
        done
        sleep {{ .Values.logShipping.rotation.intervalSeconds }}
      done
  volumeMounts:
    - name: webwork-logs-data
      mountPath: /opt/webwork/webwork2/logs
  resources:
    requests: { cpu: 10m, memory: 16Mi }
    limits:   { cpu: 50m, memory: 32Mi }
{{- end }}
{{- end -}}

{{/*
Extra volumes for the log-shipping sidecars (Fluent Bit config + buffer).
Appended to the workload `volumes:` via webwork.app.mounts when logShipping is on.
*/}}
{{- define "webwork.logShipper.volumes" -}}
- name: log-shipper-config
  configMap:
    name: {{ include "webwork.fullname" . }}-fluent-bit
- name: log-shipper-buffer
  emptyDir: {}
{{- end -}}

{{/*
Resolve the effective database provider.
  "" (empty) auto-detects from db.enabled for backward compatibility:
    db.enabled: true  → "local"
    db.enabled: false → "external"
*/}}
{{- define "webwork.db.provider" -}}
{{- if .Values.db.provider -}}
{{- .Values.db.provider -}}
{{- else if .Values.db.enabled -}}
local
{{- else -}}
external
{{- end -}}
{{- end }}

{{/*
Comma-separated names of the ESO-managed Secrets the app pods consume. Used
for the Reloader annotation so Vault rotations roll the pods (kube keeps env
secretKeyRefs frozen for a pod's lifetime).
*/}}
{{- define "webwork.reloadSecrets" -}}
{{- $s := list -}}
{{- if .Values.externalSecrets.enabled -}}
{{- $s = append $s .Values.externalSecrets.secretName -}}
{{- with .Values.externalSecrets.saml2SecretName -}}
{{- $s = append $s . -}}
{{- end -}}
{{- end -}}
{{- if and .Values.logShipping.enabled .Values.logShipping.auth.externalSecret.enabled -}}
{{- $s = append $s .Values.logShipping.auth.secretName -}}
{{- end -}}
{{- join "," $s -}}
{{- end }}

{{/*
Returns the secretKeyRef block (name + key lines) for WEBWORK_DB_PASSWORD
based on the effective provider. Indent with nindent after inclusion.
*/}}
{{- define "webwork.db.passwordSecretRef" -}}
{{- if .Values.externalSecrets.enabled -}}
name: {{ .Values.externalSecrets.secretName }}
key: db_password
{{- else if eq (include "webwork.db.provider" .) "local" -}}
name: {{ printf "%s-user-password" (include "call-nested" (list . "db" "mariadb.fullname")) }}
key: password-{{ .Values.db.auth.username }}
{{- else if eq (include "webwork.db.provider" .) "ack" -}}
name: {{ printf "%s-ack-db-password" (include "webwork.fullname" .) }}
key: password
{{- else -}}
name: {{ include "webwork.fullname" . }}
key: db_password
{{- end -}}
{{- end }}
