{{/*
Validation guards. Renders nothing; called via:
  {{- include "moodle.validateDb" . -}}
from any always-rendered file. Fails `helm template` early with an
actionable message instead of letting a misconfig boot a broken pod.
*/}}
{{- define "moodle.validateDb" -}}
{{- if not (or (eq .Values.db.type "mariadb") (eq .Values.db.type "postgres")) -}}
{{- fail (printf "db.type must be \"mariadb\" or \"postgres\", got %q" .Values.db.type) -}}
{{- end -}}
{{- if and .Values.db.enabled (eq .Values.db.type "postgres") .Values.db.mariadb.enabled -}}
{{- fail "db.type=postgres requires db.mariadb.enabled=false (the bundled mariadb subchart must be disabled)" -}}
{{- end -}}
{{- if and .Values.db.enabled (eq .Values.db.type "mariadb") (not .Values.db.mariadb.enabled) -}}
{{- fail "db.type=mariadb requires db.mariadb.enabled=true" -}}
{{- end -}}
{{- if and .Values.db.enabled .Values.externalDatabase.enabled -}}
{{- fail "db.enabled and externalDatabase.enabled are mutually exclusive" -}}
{{- end -}}
{{- if and (not .Values.db.enabled) .Values.externalDatabase.enabled .Values.db.mariadb.enabled -}}
{{- fail "externalDatabase.enabled=true requires db.mariadb.enabled=false (the bundled mariadb subchart must be disabled)" -}}
{{- end -}}
{{- if and .Values.shib.enabled (eq (include "moodle.dbDialect" .) "pgsql") -}}
{{- fail "shib.enabled=true is not supported with postgres in this chart version" -}}
{{- end -}}
{{- end -}}
