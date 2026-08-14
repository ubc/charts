{{/* Base name for all resources */}}
{{- define "ats.name" -}}
air-ticket-scanner
{{- end -}}

{{/* Name of the k8s Secret materialized from Vault (consumed by the CronJob) */}}
{{- define "ats.secretName" -}}
{{ include "ats.name" . }}-secrets
{{- end -}}

{{/* Name of the ConfigMap holding non-sensitive config */}}
{{- define "ats.configName" -}}
{{ include "ats.name" . }}-config
{{- end -}}

{{/* Common labels */}}
{{- define "ats.labels" -}}
app.kubernetes.io/name: {{ include "ats.name" . }}
app.kubernetes.io/instance: {{ .Values.env | default "default" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: air-ticket-scanner
{{- end -}}
