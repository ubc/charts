# webwork: Multi-Provider Database Provisioning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `local | ack | external` database provider selection to the webwork Helm chart, including full ACK RDS provisioning via CRDs when `db.provider: ack`.

**Architecture:** A new `db.provider` string field drives three-way template logic. A `webwork.db.provider` helper resolves backward-compat auto-detection from `db.enabled`. ACK mode renders five CRDs (ConfigMap, SecurityGroup, DBSubnetGroup, DBInstance, two FieldExports) and wires DB host/port via `configMapKeyRef` from the FieldExport target ConfigMap.

**Tech Stack:** Helm 3, ACK RDS controller (`rds.services.k8s.aws/v1alpha1`), ACK EC2 controller (`ec2.services.k8s.aws/v1alpha1`), ACK FieldExport (`services.k8s.aws/v1alpha1`).

---

## File Map

**Create:**
- `webwork/templates/ack-rds.yaml` — ConfigMap, SecurityGroup, DBSubnetGroup, DBInstance, FieldExport × 2

**Modify:**
- `webwork/values.yaml` — add `db.provider`, `db.ack.*`
- `webwork/Chart.yaml` — bump version `0.1.14` → `0.2.0`
- `webwork/templates/_helpers.tpl` — add `webwork.db.provider` + `webwork.db.passwordSecretRef` helpers; update `webwork.app.spec` DB env vars
- `webwork/templates/secret.yaml` — update `db_password` condition; add ACK password Secret block
- `webwork/templates/deployment.yaml` — update shibd container `SHIBD_ODBC_SERVER`, `SHIBD_ODBC_PORT`, `SHIB_ODBC_PASSWORD`

---

## Task 1: Add `db.provider` and `db.ack.*` to values.yaml; bump Chart.yaml version

**Files:**
- Modify: `webwork/values.yaml`
- Modify: `webwork/Chart.yaml`

- [ ] **Step 1: Add `db.provider` above `db.enabled` in values.yaml**

Open `webwork/values.yaml`. Find the `db:` section (line 179) and add `provider: ""` as the first key:

```yaml
##
## MariaDB chart configuration
# ref: https://github.com/ubc/charts/tree/master/mariadb
##
db:
  ## provider selects the database backend:
  ##   ""         auto: resolves to "local" if db.enabled=true, else "external"
  ##   "local"    bundled UBC mariadb subchart (also set db.enabled: true)
  ##   "ack"      AWS ACK RDS controller provisions a managed MariaDB instance
  ##   "external" externally-managed database; supply db.service.name and db.auth.password
  provider: ""
  ## Set to true to deploy the bundled mariadb chart. Required when provider is "local".
  enabled: false
```

- [ ] **Step 2: Add `db.ack` block to values.yaml**

After `db.service.port: 3306` (around line 219), add the following block before the `shibd:` section:

```yaml
  ack:
    # AWS region where the RDS instance will be created
    region: us-west-2
    # RDS instance class
    dbInstanceClass: db.t3.medium
    # MariaDB engine version
    engineVersion: "10.6"
    # Allocated storage in GiB
    allocatedStorage: 20
    storageType: gp3
    storageEncrypted: true
    # Enable Multi-AZ deployment
    multiAZ: false
    # VPC ID for the SecurityGroup (required when provider is "ack")
    vpcId: ""
    # Subnet IDs for the DBSubnetGroup (required when provider is "ack"; at least two)
    subnetIDs: []
    # CIDR blocks allowed to reach RDS on port 3306
    ingressCIDRs:
      - 10.0.0.0/8
```

- [ ] **Step 3: Bump Chart.yaml version**

In `webwork/Chart.yaml`, change:
```yaml
version: 0.1.14
```
to:
```yaml
version: 0.2.0
```

- [ ] **Step 4: Verify helm template renders with defaults**

```bash
helm template test-release webwork/ | grep -c "apiVersion"
```

Expected: a positive number (chart renders without error).

- [ ] **Step 5: Commit**

```bash
git add webwork/values.yaml webwork/Chart.yaml
git commit -m "feat(webwork): add db.provider field and db.ack.* values for ACK RDS support"
```

---

## Task 2: Add `webwork.db.provider` and `webwork.db.passwordSecretRef` helpers

**Files:**
- Modify: `webwork/templates/_helpers.tpl`

- [ ] **Step 1: Add `webwork.db.provider` helper**

Append the following to the end of `webwork/templates/_helpers.tpl`:

```
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
Returns the secretKeyRef block (name + key lines) for WEBWORK_DB_PASSWORD
based on the effective provider. Indent with nindent after inclusion.
*/}}
{{- define "webwork.db.passwordSecretRef" -}}
{{- if eq (include "webwork.db.provider" .) "local" -}}
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
```

- [ ] **Step 2: Verify helper renders correctly for each provider**

```bash
# local provider (backward compat via db.enabled)
helm template test-release webwork/ --set db.enabled=true 2>/dev/null | grep -A2 "WEBWORK_DB_PASSWORD" | head -6

# ack provider
helm template test-release webwork/ --set db.provider=ack 2>/dev/null | grep -A4 "WEBWORK_DB_PASSWORD" | head -8

# external provider (default)
helm template test-release webwork/ 2>/dev/null | grep -A2 "WEBWORK_DB_PASSWORD" | head -6
```

Expected for `ack`:
```
- name: WEBWORK_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: test-release-webwork-ack-db-password
      key: password
```

Note: The `WEBWORK_DB_PASSWORD` env var update happens in Task 4. These helpers just need to exist and be callable. The grep above may not yet show the new format until Task 4 is complete — run it to confirm the helpers at least parse without error.

- [ ] **Step 3: Commit**

```bash
git add webwork/templates/_helpers.tpl
git commit -m "feat(webwork): add db provider and password secret ref helpers"
```

---

## Task 3: Update `secret.yaml` — update `db_password` condition and add ACK password Secret

**Files:**
- Modify: `webwork/templates/secret.yaml`

- [ ] **Step 1: Replace the `db.enabled` condition on `db_password` key**

In `webwork/templates/secret.yaml`, find:
```yaml
  {{- if not .Values.db.enabled }}
  db_password: {{ $dbPassword | b64enc | quote }}
  {{- end }}
```

Replace with:
```yaml
  {{- if eq (include "webwork.db.provider" .) "external" }}
  db_password: {{ $dbPassword | b64enc | quote }}
  {{- end }}
```

- [ ] **Step 2: Append the ACK password Secret block at the end of secret.yaml**

Add the following after the last `{{- end }}` in the file:

```yaml
{{- if eq (include "webwork.db.provider" .) "ack" }}
{{- $ackSecretName := printf "%s-ack-db-password" (include "webwork.fullname" .) }}
{{- $ackSecretObj := lookup "v1" "Secret" .Release.Namespace $ackSecretName }}
{{- $ackDbPassword := "" }}
{{- if .Values.db.auth.password }}
{{- $ackDbPassword = .Values.db.auth.password }}
{{- else if $ackSecretObj }}
{{- $ackDbPassword = index $ackSecretObj.data "password" | b64dec }}
{{- else }}
{{- $ackDbPassword = randAlphaNum 16 }}
{{- end }}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "webwork.fullname" . }}-ack-db-password
  labels:
    {{- include "webwork.labels" . | nindent 4 }}
type: Opaque
data:
  password: {{ $ackDbPassword | b64enc | quote }}
{{- end }}
```

- [ ] **Step 3: Verify external provider still emits db_password**

```bash
helm template test-release webwork/ | grep "db_password"
```

Expected: `db_password:` key appears in the Secret (external is the default).

- [ ] **Step 4: Verify ack provider emits the ack-db-password Secret**

```bash
helm template test-release webwork/ --set db.provider=ack | grep -A5 "ack-db-password"
```

Expected output includes:
```yaml
  name: test-release-webwork-ack-db-password
```
and a `password:` key with a base64-encoded value.

- [ ] **Step 5: Verify local provider emits neither db_password key nor ack-db-password Secret**

```bash
helm template test-release webwork/ --set db.enabled=true --set db.provider=local | grep -E "db_password|ack-db-password"
```

Expected: no output (neither key is rendered for local provider).

- [ ] **Step 6: Commit**

```bash
git add webwork/templates/secret.yaml
git commit -m "feat(webwork): add ACK password secret and fix db_password condition for provider logic"
```

---

## Task 4: Update `webwork.app.spec` in `_helpers.tpl` for ACK DB env vars

**Files:**
- Modify: `webwork/templates/_helpers.tpl`

This task updates five env vars in the `webwork.app.spec` helper: `WEBWORK_DB_HOST`, `WEBWORK_DB_PORT`, `WEBWORK_DB_PASSWORD`, `SHIBD_ODBC_SERVER`, `SHIBD_ODBC_PORT`, and `SHIB_ODBC_PASSWORD`.

- [ ] **Step 1: Replace `WEBWORK_DB_HOST` in `webwork.app.spec`**

Find in `_helpers.tpl`:
```
- name: WEBWORK_DB_HOST
  value: {{ template "app.db.fullname" . }}
```

Replace with:
```
- name: WEBWORK_DB_HOST
{{- if eq (include "webwork.db.provider" .) "ack" }}
  valueFrom:
    configMapKeyRef:
      name: {{ printf "%s-rds-endpoint" (include "webwork.fullname" .) }}
      key: endpoint
{{- else }}
  value: {{ template "app.db.fullname" . }}
{{- end }}
```

- [ ] **Step 2: Replace `WEBWORK_DB_PORT` in `webwork.app.spec`**

Find in `_helpers.tpl`:
```
- name: WEBWORK_DB_PORT
  value: {{ .Values.db.service.port | quote }}
```

Replace with:
```
- name: WEBWORK_DB_PORT
{{- if eq (include "webwork.db.provider" .) "ack" }}
  valueFrom:
    configMapKeyRef:
      name: {{ printf "%s-rds-endpoint" (include "webwork.fullname" .) }}
      key: port
{{- else }}
  value: {{ .Values.db.service.port | quote }}
{{- end }}
```

- [ ] **Step 3: Replace `WEBWORK_DB_PASSWORD` in `webwork.app.spec`**

Find in `_helpers.tpl`:
```
- name: WEBWORK_DB_PASSWORD
  valueFrom:
    secretKeyRef:
    {{- if .Values.db.enabled }}
      name: {{ printf "%s-user-password" (include "call-nested" (list . "db" "mariadb.fullname")) }}
      key: password-{{ .Values.db.auth.username }}
    {{- else }}
      name: {{ include "webwork.fullname" . }}
      key: db_password
    {{- end }}
```

Replace with:
```
- name: WEBWORK_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- include "webwork.db.passwordSecretRef" . | nindent 6 }}
```

- [ ] **Step 4: Replace `SHIBD_ODBC_SERVER` in `webwork.app.spec`**

Find in `_helpers.tpl`:
```
- name: SHIBD_ODBC_SERVER
  value: {{ template "app.db.fullname" . }}
```

Replace with:
```
- name: SHIBD_ODBC_SERVER
{{- if eq (include "webwork.db.provider" .) "ack" }}
  valueFrom:
    configMapKeyRef:
      name: {{ printf "%s-rds-endpoint" (include "webwork.fullname" .) }}
      key: endpoint
{{- else }}
  value: {{ template "app.db.fullname" . }}
{{- end }}
```

- [ ] **Step 5: Replace `SHIBD_ODBC_PORT` in `webwork.app.spec`**

Find in `_helpers.tpl`:
```
- name: SHIBD_ODBC_PORT
  value: {{ .Values.db.service.port | quote }}
```

Replace with:
```
- name: SHIBD_ODBC_PORT
{{- if eq (include "webwork.db.provider" .) "ack" }}
  valueFrom:
    configMapKeyRef:
      name: {{ printf "%s-rds-endpoint" (include "webwork.fullname" .) }}
      key: port
{{- else }}
  value: {{ .Values.db.service.port | quote }}
{{- end }}
```

- [ ] **Step 6: Replace `SHIB_ODBC_PASSWORD` in `webwork.app.spec`**

Find in `_helpers.tpl`:
```
- name: SHIB_ODBC_PASSWORD
  valueFrom:
    secretKeyRef:
    {{- if .Values.db.enabled }}
      name: {{ printf "%s-user-password" (include "call-nested" (list . "db" "mariadb.fullname")) }}
      key: password-{{ .Values.db.auth.username }}
    {{- else }}
      name: {{ include "webwork.fullname" . }}
      key: db_password
    {{- end }}
```

Replace with:
```
- name: SHIB_ODBC_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- include "webwork.db.passwordSecretRef" . | nindent 6 }}
```

- [ ] **Step 7: Verify ACK provider renders configMapKeyRef for DB_HOST**

```bash
helm template test-release webwork/ --set db.provider=ack | grep -A5 "WEBWORK_DB_HOST"
```

Expected:
```yaml
- name: WEBWORK_DB_HOST
  valueFrom:
    configMapKeyRef:
      name: test-release-webwork-rds-endpoint
      key: endpoint
```

- [ ] **Step 8: Verify default (external) provider still renders value: for DB_HOST**

```bash
helm template test-release webwork/ | grep -A2 "WEBWORK_DB_HOST"
```

Expected:
```yaml
- name: WEBWORK_DB_HOST
  value: test-release-db
```

- [ ] **Step 9: Commit**

```bash
git add webwork/templates/_helpers.tpl
git commit -m "feat(webwork): update webwork.app.spec to use ACK configMapKeyRef for db host/port and unified password helper"
```

---

## Task 5: Update shibd container DB env vars in `deployment.yaml`

**Files:**
- Modify: `webwork/templates/deployment.yaml`

The shibd container in `deployment.yaml` duplicates some DB env vars independently of `webwork.app.spec`. Update `SHIBD_ODBC_SERVER`, `SHIBD_ODBC_PORT`, and `SHIB_ODBC_PASSWORD` in the shibd Deployment section.

- [ ] **Step 1: Replace `SHIBD_ODBC_PORT` in the shibd container**

In `deployment.yaml`, find the shibd container env section (look for `SHIBD_ODBC_DATABASE`). Find:
```yaml
        - name: SHIBD_ODBC_PORT
          value: {{ .Values.db.service.port | quote }}
```

Replace with:
```yaml
        - name: SHIBD_ODBC_PORT
          {{- if eq (include "webwork.db.provider" .) "ack" }}
          valueFrom:
            configMapKeyRef:
              name: {{ printf "%s-rds-endpoint" (include "webwork.fullname" .) }}
              key: port
          {{- else }}
          value: {{ .Values.db.service.port | quote }}
          {{- end }}
```

- [ ] **Step 2: Replace `SHIBD_ODBC_SERVER` in the shibd container**

Find:
```yaml
        - name: SHIBD_ODBC_SERVER
          value: {{ template "app.db.fullname" . }}
```

Replace with:
```yaml
        - name: SHIBD_ODBC_SERVER
          {{- if eq (include "webwork.db.provider" .) "ack" }}
          valueFrom:
            configMapKeyRef:
              name: {{ printf "%s-rds-endpoint" (include "webwork.fullname" .) }}
              key: endpoint
          {{- else }}
          value: {{ template "app.db.fullname" . }}
          {{- end }}
```

- [ ] **Step 3: Replace `SHIB_ODBC_PASSWORD` in the shibd container**

Find:
```yaml
        - name: SHIB_ODBC_PASSWORD
          valueFrom:
            secretKeyRef:
            {{- if .Values.db.enabled }}
              name: {{ printf "%s-user-password" (include "call-nested" (list . "db" "mariadb.fullname")) }}
              key: password-{{ .Values.db.auth.username }}
            {{- else }}
              name: {{ include "webwork.fullname" . }}
              key: db_password
            {{- end }}
```

Replace with:
```yaml
        - name: SHIB_ODBC_PASSWORD
          valueFrom:
            secretKeyRef:
              {{- include "webwork.db.passwordSecretRef" . | nindent 14 }}
```

- [ ] **Step 4: Verify shibd renders configMapKeyRef when provider is ack**

```bash
helm template test-release webwork/ --set db.provider=ack --set shibd.enabled=true \
  --set "shibd.idp.discovery_url=https://example.com" \
  --set "shibd.idp.metadata_url=https://example.com/idp" \
  --set "shibd_idp.entity_id=https://example.com" \
  --set "shibd.sp.entity_id=https://sp.example.com" \
  --set "shibd.idp.attribute_map_url=https://example.com/attr" \
  | grep -A5 "SHIBD_ODBC_SERVER"
```

Expected:
```yaml
        - name: SHIBD_ODBC_SERVER
          valueFrom:
            configMapKeyRef:
              name: test-release-webwork-rds-endpoint
              key: endpoint
```

- [ ] **Step 5: Commit**

```bash
git add webwork/templates/deployment.yaml
git commit -m "feat(webwork): update shibd container to use ACK configMapKeyRef for db host/port"
```

---

## Task 6: Create `templates/ack-rds.yaml`

**Files:**
- Create: `webwork/templates/ack-rds.yaml`

- [ ] **Step 1: Create the file with all ACK resources**

Create `webwork/templates/ack-rds.yaml` with the following content:

```yaml
{{- if eq (include "webwork.db.provider" .) "ack" }}
{{- required "db.ack.vpcId is required when db.provider is ack" .Values.db.ack.vpcId }}
{{- if not .Values.db.ack.subnetIDs }}
{{- fail "db.ack.subnetIDs must contain at least one entry when db.provider is ack" }}
{{- end }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "webwork.fullname" . }}-rds-endpoint
  labels:
    {{- include "webwork.labels" . | nindent 4 }}
data:
  endpoint: ""
  port: ""
---
apiVersion: ec2.services.k8s.aws/v1alpha1
kind: SecurityGroup
metadata:
  name: {{ include "webwork.fullname" . }}-rds-sg
  labels:
    {{- include "webwork.labels" . | nindent 4 }}
spec:
  name: {{ include "webwork.fullname" . }}-rds-sg
  description: Security group for {{ include "webwork.fullname" . }} RDS MariaDB instance
  vpcID: {{ .Values.db.ack.vpcId | quote }}
  ingressRules:
  {{- range .Values.db.ack.ingressCIDRs }}
  - ipProtocol: tcp
    fromPort: 3306
    toPort: 3306
    ipRanges:
    - cidrIP: {{ . | quote }}
  {{- end }}
---
apiVersion: rds.services.k8s.aws/v1alpha1
kind: DBSubnetGroup
metadata:
  name: {{ include "webwork.fullname" . }}-db-subnet-group
  labels:
    {{- include "webwork.labels" . | nindent 4 }}
spec:
  name: {{ include "webwork.fullname" . }}-db-subnet-group
  description: DB subnet group for {{ include "webwork.fullname" . }}
  subnetIDs:
  {{- range .Values.db.ack.subnetIDs }}
  - {{ . | quote }}
  {{- end }}
---
apiVersion: rds.services.k8s.aws/v1alpha1
kind: DBInstance
metadata:
  name: {{ include "webwork.fullname" . }}
  labels:
    {{- include "webwork.labels" . | nindent 4 }}
spec:
  dbInstanceIdentifier: {{ include "webwork.fullname" . }}
  dbInstanceClass: {{ .Values.db.ack.dbInstanceClass | quote }}
  engine: mariadb
  engineVersion: {{ .Values.db.ack.engineVersion | quote }}
  masterUsername: {{ .Values.db.auth.username | quote }}
  masterUserPassword:
    name: {{ include "webwork.fullname" . }}-ack-db-password
    key: password
  dbName: {{ .Values.db.auth.database | quote }}
  allocatedStorage: {{ .Values.db.ack.allocatedStorage }}
  dbSubnetGroupName: {{ include "webwork.fullname" . }}-db-subnet-group
  vpcSecurityGroupRefs:
  - from:
      name: {{ include "webwork.fullname" . }}-rds-sg
  # NOTE: vpcSecurityGroupRefs is an ACK cross-resource reference supported in
  # rds-controller >= 0.1.x. If your ACK RDS controller version does not support it,
  # replace with:
  #   vpcSecurityGroupIDs:
  #   - <sg-id>   # supply after the SecurityGroup CRD is reconciled
  multiAZ: {{ .Values.db.ack.multiAZ }}
  storageType: {{ .Values.db.ack.storageType | quote }}
  storageEncrypted: {{ .Values.db.ack.storageEncrypted }}
---
apiVersion: services.k8s.aws/v1alpha1
kind: FieldExport
metadata:
  name: {{ include "webwork.fullname" . }}-rds-endpoint-address
  labels:
    {{- include "webwork.labels" . | nindent 4 }}
spec:
  from:
    resource:
      group: rds.services.k8s.aws
      kind: DBInstance
      name: {{ include "webwork.fullname" . }}
    path: .status.endpoint.address
  to:
    kind: ConfigMap
    name: {{ include "webwork.fullname" . }}-rds-endpoint
    namespace: {{ .Release.Namespace }}
    key: endpoint
---
apiVersion: services.k8s.aws/v1alpha1
kind: FieldExport
metadata:
  name: {{ include "webwork.fullname" . }}-rds-endpoint-port
  labels:
    {{- include "webwork.labels" . | nindent 4 }}
spec:
  from:
    resource:
      group: rds.services.k8s.aws
      kind: DBInstance
      name: {{ include "webwork.fullname" . }}
    path: .status.endpoint.port
  to:
    kind: ConfigMap
    name: {{ include "webwork.fullname" . }}-rds-endpoint
    namespace: {{ .Release.Namespace }}
    key: port
{{- end }}
```

- [ ] **Step 2: Verify ack-rds.yaml renders all six resources**

```bash
helm template test-release webwork/ \
  --set db.provider=ack \
  --set db.ack.vpcId=vpc-12345678 \
  --set "db.ack.subnetIDs[0]=subnet-aaa" \
  --set "db.ack.subnetIDs[1]=subnet-bbb" \
  | grep "^kind:"
```

Expected (six `kind:` lines):
```
kind: Secret
kind: ConfigMap
kind: SecurityGroup
kind: DBSubnetGroup
kind: DBInstance
kind: FieldExport
kind: FieldExport
```

(The `Secret` line comes from `secret.yaml` rendering the `ack-db-password` Secret.)

- [ ] **Step 3: Verify required-field validation fires when vpcId is missing**

```bash
helm template test-release webwork/ \
  --set db.provider=ack \
  --set "db.ack.subnetIDs[0]=subnet-aaa" \
  2>&1 | grep "required"
```

Expected: error message containing `db.ack.vpcId is required when db.provider is ack`.

- [ ] **Step 4: Verify default provider renders zero ACK resources**

```bash
helm template test-release webwork/ | grep -E "SecurityGroup|DBSubnetGroup|DBInstance|FieldExport"
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add webwork/templates/ack-rds.yaml
git commit -m "feat(webwork): add ACK RDS template with SecurityGroup, DBSubnetGroup, DBInstance, and FieldExports"
```

---

## Task 7: Lint and final verification

**Files:** none (verification only)

- [ ] **Step 1: Run helm lint with default values**

```bash
helm lint webwork/
```

Expected: `1 chart(s) linted, 0 chart(s) failed`

- [ ] **Step 2: Run helm lint with ACK values**

```bash
helm lint webwork/ \
  --set db.provider=ack \
  --set db.ack.vpcId=vpc-12345678 \
  --set "db.ack.subnetIDs[0]=subnet-aaa" \
  --set "db.ack.subnetIDs[1]=subnet-bbb"
```

Expected: `1 chart(s) linted, 0 chart(s) failed`

- [ ] **Step 3: Run helm lint with local values**

```bash
helm lint webwork/ --set db.enabled=true --set db.provider=local
```

Expected: `1 chart(s) linted, 0 chart(s) failed`

- [ ] **Step 4: Verify full ACK template output is well-formed YAML**

```bash
helm template test-release webwork/ \
  --set db.provider=ack \
  --set db.ack.vpcId=vpc-12345678 \
  --set "db.ack.subnetIDs[0]=subnet-aaa" \
  --set "db.ack.subnetIDs[1]=subnet-bbb" \
  | python3 -c "import sys, yaml; list(yaml.safe_load_all(sys.stdin)); print('YAML valid')"
```

Expected: `YAML valid`

- [ ] **Step 5: Run ct lint (mirrors CI)**

```bash
ct lint --config .github/ct-lint.yaml --target-branch master
```

Expected: `All charts linted successfully`

Note: `ct lint` only lints charts that have changed relative to `master`. If the command reports no changed charts, run `helm lint webwork/` directly to confirm the chart is clean.

- [ ] **Step 6: Commit if any lint fixes were needed**

If steps 1–5 required any fixes, commit them:

```bash
git add webwork/
git commit -m "fix(webwork): address lint issues in db provisioning templates"
```

---

## Backward Compatibility Verification

After all tasks are complete, confirm existing users are unaffected:

```bash
# Simulates a user who previously had db.enabled: false (external)
helm template old-external webwork/ | grep -E "WEBWORK_DB_HOST|db_password"
```

Expected:
- `WEBWORK_DB_HOST` has `value:` form (not `configMapKeyRef`)
- `db_password:` key appears in the Secret

```bash
# Simulates a user who previously had db.enabled: true (local mariadb)
helm template old-local webwork/ --set db.enabled=true | grep "WEBWORK_DB_HOST"
```

Expected: `WEBWORK_DB_HOST` has `value:` form using the mariadb subchart hostname.
