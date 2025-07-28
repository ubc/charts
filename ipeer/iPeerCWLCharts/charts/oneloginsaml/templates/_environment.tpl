{{/*
Runtime environment variables
*/}}
{{- define "glu.environment" }}
- name: SECRET_KEY
  value: {{ .Values.secretKey | quote }}
  # valueFrom:
  #   secretKeyRef: 
  #     name: {{ template "oneloginsaml.fullname" . }}
  #     key: secret_key 
- name: GLU_BATCH_ENABLED
  value: {{ .Values.glu.batchEnabled | quote }}
- name: GLU_BATCH_GROUP_SYNC_SCHEDULE
  value: {{ .Values.glu.batchGroupSyncSchedule | quote }}
- name: GLU_BATCH_GROUP_SYNC_MUTEX_TTL
  value: {{ .Values.glu.batchGroupSyncMutexTtl | quote }}
- name: GLU_SCRAMBLE_EMAIL
  value: {{ .Values.glu.scrambleEmail | quote }}
- name: GLU_RENAME_API_NETWORK_MASK
  value: {{ .Values.glu.renameApiNetworkMask | quote }}
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
  #     name: {{ template "oneloginsaml.fullname" . }}
  #     key: saml_settings
- name: SAML_METADATA_URL
  value: {{ .Values.saml.metadataUrl | quote }}
- name: SAML_LOGOUT_URL
  value: {{ .Values.saml.logoutUrl | default "https://authentication.ubc.ca/idp/profile/Logout" | quote }}
- name: SAML_METADATA_ENTITY_ID
  value: {{ .Values.saml.metadataEntityId | quote }}
- name: SAML_EXPOSE_METADATA_ENDPOINT
  value: {{ .Values.saml.exposeMetadataEndpoint | quote }}
- name: SAML_FORCE_RESP_HTTPS
  value: {{ .Values.saml.forceRespHttps | quote }}
- name: SAML_JWT_SECRET_KEY
  value: {{ .Values.saml.jwtSecretKey | quote }}
- name: SAML_JWT_SECRET_KEY_EXPIRATION
  value: {{ .Values.saml.jwtSecretKeyExpiration | quote }}
- name: SAML_JWT_PARM
  value: {{ .Values.saml.jwtSecretKeyParm | quote }}
{{- end }}
