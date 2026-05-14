{{/*
Validation guards. Renders nothing; called via:
  {{- include "canvas-bridge.validate" . -}}
from any always-rendered file. Fails `helm template` early with an
actionable message instead of letting a misconfig boot a broken pod.
*/}}
{{- define "canvas-bridge.validate" -}}
{{- if not .Values.app.baseUrl -}}
{{- fail "app.baseUrl is required (e.g. https://canvas-bridge-stg.ltic.ubc.ca)" -}}
{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.host) -}}
{{- fail "ingress.host is required when ingress.enabled=true" -}}
{{- end -}}
{{- if not .Values.externalSecret.secretStoreRefName -}}
{{- fail "externalSecret.secretStoreRefName is required" -}}
{{- end -}}
{{- if not .Values.externalSecret.path -}}
{{- fail "externalSecret.path is required (e.g. canvas-bridge/staging)" -}}
{{- end -}}
{{- end -}}
