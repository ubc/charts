{{/*
Runtime environment variables
*/}}
{{- define "glu.environment" }}
- name: SECRET_KEY
  value: {{ .Values.secretKey | quote }}
  # valueFrom:
  #   secretKeyRef:
  #     name: {{ template "github-learning-ubc.fullname" . }}
  #     key: secret_key
- name: GLU_BATCH_ENABLED
  value: {{ .Values.glu.batchEnabled | quote }}
- name: GLU_BATCH_GROUP_SYNC_SCHEDULE
  value: {{ .Values.glu.batchGroupSyncSchedule | quote }}
- name: CELERY_BROKER_URL
  value: "redis://{{ template "github-learning-ubc.fullname" . }}-redis:{{ .Values.redis.service.port }}"
- name: CELERY_ALWAYS_EAGER
  value: {{ .Values.celery.alwaysEager | quote }}
- name: SAML_ATTRIBUTE_USERNAME
  value: {{ .Values.saml.attributeUsername | quote }}
- name: SAML_ATTRIBUTE_FIRST_NAME
  value: {{ .Values.saml.attributeFirstName | quote }}
- name: SAML_ATTRIBUTE_LAST_NAME
  value: {{ .Values.saml.attributeLastName | quote }}
- name: SAML_SETTINGS_FILE
  value: {{ .Values.saml.settingsFile | quote }}
- name: SAML_SETTINGS
  value: {{ .Values.saml.settings | quote }}
  # valueFrom:
  #   secretKeyRef:
  #     name: {{ template "github-learning-ubc.fullname" . }}
  #     key: saml_settings
- name: SAML_METADATA_URL
  value: {{ .Values.saml.metadataUrl | quote }}
- name: SAML_METADATA_ENTITY_ID
  value: {{ .Values.saml.metadataEntityId | quote }}
- name: SAML_EXPOSE_METADATA_ENDPOINT
  value: {{ .Values.saml.exposeMetadataEndpoint | quote }}
- name: SAML_FORCE_RESP_HTTPS
  value: {{ .Values.saml.forceRespHttps | quote }}
- name: LDAP_USE_TLS
  value: {{ .Values.ldap.useTls | quote }}
- name: LDAP_VALIDATE_CERT
  value: {{ .Values.ldap.validateCert | quote }}
- name: LDAP_CONN_TIMEOUT
  value: {{ .Values.ldap.connTimeout | quote }}
- name: LDAP_USE_POOL
  value: {{ .Values.ldap.usePool | quote }}
- name: LDAP_POOL_MAX_LIFETIME
  value: {{ .Values.ldap.poolMaxLifetime | quote }}
- name: LDAP_IDM_CONSUMER_URL
  value: {{ .Values.ldap.idmConsumerUrl | quote }}
- name: LDAP_IDM_CONSUMER_SERVICE_BIND_DN
  value: {{ .Values.ldap.idmConsumerServiceBindDn | quote }}
- name: LDAP_IDM_CONSUMER_SERVICE_PASSWORD
  value: {{ .Values.ldap.idmConsumerServicePassword | quote }}
  # valueFrom:
  #   secretKeyRef:
  #     name: {{ template "github-learning-ubc.fullname" . }}
  #     key: ldap_idm_consumer_service_password
- name: LDAP_IDM_CONSUMER_USER_BASE_DN
  value: {{ .Values.ldap.idmConsumerUserBaseDn | quote }}
- name: LDAP_IDM_CONSUMER_USER_UNIQUE_IDENTIFIER
  value: {{ .Values.ldap.idmConsumerUserUniqueIdentifier | quote }}
- name: LDAP_INT_PROVIDER_URL
  value: {{ .Values.ldap.intProviderUrl | quote }}
- name: LDAP_INT_PROVIDER_SERVICE_BIND_DN
  value: {{ .Values.ldap.intProviderServiceBindDn | quote }}
- name: LDAP_INT_PROVIDER_SERVICE_PASSWORD
  value: {{ .Values.ldap.intProviderServicePassword | quote }}
  # valueFrom:
  #   secretKeyRef:
  #     name: {{ template "github-learning-ubc.fullname" . }}
  #     key: ldap_int_provider_service_password
- name: LDAP_INT_CONSUMER_URL
  value: {{ .Values.ldap.intConsumerUrl | quote }}
- name: LDAP_INT_CONSUMER_SERVICE_BIND_DN
  value: {{ .Values.ldap.intConsumerServiceBindDn | quote }}
- name: LDAP_INT_CONSUMER_SERVICE_PASSWORD
  value: {{ .Values.ldap.intConsumerServicePassword | quote }}
  # valueFrom:
  #   secretKeyRef:
  #     name: {{ template "github-learning-ubc.fullname" . }}
  #     key: ldap_int_consumer_service_password
- name: LDAP_INT_USER_UNIQUE_IDENTIFIER
  value: {{ .Values.ldap.intUserUniqueIdentifier | quote }}
- name: LDAP_INT_USER_BASE_DN
  value: {{ .Values.ldap.intUserBaseDn | quote }}
- name: LDAP_INT_GROUPS_SRC_BASE_DN
  value: {{ .Values.ldap.intGroupsSrcBaseDn | quote }}
- name: LDAP_INT_GROUPS_BASE_DN
  value: {{ .Values.ldap.intGroupsBaseDn | quote }}
{{- end }}