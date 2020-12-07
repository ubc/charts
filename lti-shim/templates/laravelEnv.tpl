{{- define "laravelEnv" -}}
APP_NAME="LTI Shim"
APP_ENV={{ .Values.mode }}
# run 'artisan key:generate' to generate a new key
APP_KEY={{ .Values.app.key }}
APP_DEBUG=false
{{- if and (hasKey .Values.ingress.annotations "kubernetes.io/tls-acme") (eq (index .Values.ingress.annotations "kubernetes.io/tls-acme") "true") }}
APP_URL=https://{{ .Values.ingress.host }}
FORCE_HTTPS=true
{{- else }}
APP_URL=http://{{ .Values.ingress.host }}
{{- end }}

LOG_CHANNEL=stack

DB_CONNECTION=pgsql
DB_HOST={{ .Values.postgres.host }}
DB_PORT={{ .Values.postgres.port }}
DB_DATABASE={{ .Values.postgres.database }}
DB_USERNAME={{ .Values.postgres.username }}
DB_PASSWORD={{ .Values.postgres.password }}

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=database
SESSION_LIFETIME=120
# Require cookies to use https only
SESSION_SECURE_COOKIE=false

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_DRIVER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_APP_CLUSTER=mt1

MIX_PUSHER_APP_KEY="${PUSHER_APP_KEY}"
MIX_PUSHER_APP_CLUSTER="${PUSHER_APP_CLUSTER}"
{{- end -}}
