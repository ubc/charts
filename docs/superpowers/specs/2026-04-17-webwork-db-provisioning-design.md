# webwork: Multi-Provider Database Provisioning

**Date:** 2026-04-17
**Chart:** `webwork/`
**Status:** Approved

## Overview

Add support for three database provisioning modes to the webwork Helm chart:

- `local` — bundled UBC mariadb subchart (existing behavior when `db.enabled: true`)
- `ack` — AWS ACK controller provisions an RDS MariaDB instance via Kubernetes CRDs
- `external` — externally-managed database, connection details provided by the user (existing behavior when `db.enabled: false`)

The selector is a new `db.provider` string field. The existing `db.enabled` boolean is preserved for backward compatibility and continues to control subchart loading.

## Values Structure

```yaml
db:
  provider: ""   # "" | "local" | "ack" | "external"
                 # "" = auto: resolves to "local" if db.enabled=true, else "external"
  enabled: false # still controls mariadb subchart loading; must be true when provider: local

  auth:
    username: webwork
    database: webwork
    password: ""  # auto-generated if empty (used by local and ack providers)

  service:
    port: 3306
    name: ""       # external only: hostname or service name
    endpoints: []  # external only: IP list for headless service

  # Existing local mariadb config (unchanged)
  architecture: standalone
  db:
    type: mariadb
    driver: MariaDB
  # ... myCnf, persistence, replicationPassword, etc.

  # ACK RDS config (used only when provider: ack)
  ack:
    region: us-west-2
    dbInstanceClass: db.t3.medium
    engineVersion: "10.6"
    allocatedStorage: 20
    storageType: gp3
    storageEncrypted: true
    multiAZ: false
    vpcId: ""        # required: VPC ID for SecurityGroup
    subnetIDs: []    # required: subnet IDs for DBSubnetGroup
    ingressCIDRs:    # CIDR blocks allowed on port 3306
      - 10.0.0.0/8
```

## Architecture

### Provider: `local`

Behavior unchanged from current `db.enabled: true` path. The mariadb subchart is loaded via `Chart.yaml` condition `db.enabled`. Templates resolve the DB hostname via the existing `app.db.fullname` helper. Password comes from the mariadb subchart-managed Secret.

### Provider: `ack`

The chart renders four ACK CRDs into `templates/ack-rds.yaml`:

1. **`ec2.services.k8s.aws/SecurityGroup`** — creates a VPC security group in `db.ack.vpcId` with an ingress rule allowing TCP port 3306 from each CIDR in `db.ack.ingressCIDRs`.

2. **`rds.services.k8s.aws/DBSubnetGroup`** — creates a DB subnet group from `db.ack.subnetIDs`.

3. **`rds.services.k8s.aws/DBInstance`** — creates a MariaDB RDS instance. References the SecurityGroup via ACK cross-resource ref (`vpcSecurityGroupRefs`) if supported by the installed ACK RDS controller version; falls back to `vpcSecurityGroupIDs` requiring the user to supply the SG ID in `db.ack.vpcSecurityGroupIDs` after the SecurityGroup is created. References the subnet group by Kubernetes resource name. Master password is read from the chart-managed Secret (`<fullname>-ack-db-password`).

4. **Two `services.k8s.aws/FieldExport` CRDs** — export `status.endpoint.address` and `status.endpoint.port` from the DBInstance into a ConfigMap named `<fullname>-rds-endpoint`. The app Deployment reads `WEBWORK_DB_HOST` and `WEBWORK_DB_PORT` from this ConfigMap via `configMapKeyRef`.

5. **`ConfigMap` (`<fullname>-rds-endpoint`)** — pre-created by the chart with empty `endpoint` and `port` keys. This ensures the Pod can be scheduled immediately (not stuck in Pending due to a missing ConfigMap) while RDS is provisioning. ACK FieldExport overwrites the values once the DBInstance endpoint is available.

### Provider: `external`

Behavior unchanged from current `db.enabled: false` path. `WEBWORK_DB_HOST` resolves via `app.db.fullname` (uses `db.service.name` or `<release>-db`). Password comes from the `<fullname>` Secret with key `db_password`.

## Template Changes

### New: `templates/ack-rds.yaml`

Rendered only when `db.provider == "ack"`. Contains the SecurityGroup, DBSubnetGroup, DBInstance, and two FieldExport resources separated by `---`.

### Modified: `templates/secret.yaml`

When `db.provider == "ack"`, renders an additional Secret `<fullname>-ack-db-password` with key `password`. Password resolution order:

1. Look up existing Secret `<fullname>-ack-db-password` — reuse `password` key if found
2. Use `db.auth.password` from values if non-empty
3. Generate `randAlphaNum 16`

This ensures the password is stable across `helm upgrade` runs.

The existing `db_password` key in the `<fullname>` Secret is rendered only for `provider: external` (unchanged behavior).

### Modified: `templates/_helpers.tpl`

**`app.db.fullname`**: Add `ack` branch returning `""`. The ACK endpoint is not a static string resolvable at template time — it comes from the FieldExport ConfigMap.

**New helper `webwork.db.passwordSecretRef`**: Returns the correct `secretKeyRef` block for `WEBWORK_DB_PASSWORD`:

```
local    → name: <mariadb-fullname>-user-password  key: password-<username>
ack      → name: <fullname>-ack-db-password         key: password
external → name: <fullname>                          key: db_password
```

**`webwork.app.spec`**: Update `WEBWORK_DB_HOST` and `WEBWORK_DB_PORT` env entries:

- For `ack`: use `configMapKeyRef` pointing to `<fullname>-rds-endpoint` (keys: `endpoint`, `port`)
- For `local` / `external`: keep existing `value:` form using `app.db.fullname` and `db.service.port`

Use the new `webwork.db.passwordSecretRef` helper for `WEBWORK_DB_PASSWORD` and `SHIB_ODBC_PASSWORD`.

### Modified: `Chart.yaml`

Version bumped from `0.1.14` → `0.2.0`. The mariadb dependency condition remains `db.enabled` (unchanged).

## Credential Summary

| Provider | Secret name | Key | Managed by |
|---|---|---|---|
| `local` | `<mariadb-fullname>-user-password` | `password-<username>` | mariadb subchart |
| `ack` | `<fullname>-ack-db-password` | `password` | this chart |
| `external` | `<fullname>` | `db_password` | this chart |

## Backward Compatibility

Existing deployments using `db.enabled: true` or `db.enabled: false` require no values changes. When `db.provider` is empty, template logic resolves the effective provider as `"local"` if `db.enabled` is true, otherwise `"external"`. This matches current behavior exactly.

New ACK deployments must set `db.provider: ack` and populate `db.ack.*` fields. They should leave `db.enabled: false`.

## Operational Notes

- **Startup delay**: When `provider: ack`, the app Deployment will fail readiness until ACK finishes provisioning the RDS instance (typically 5–10 minutes) and the FieldExport populates the ConfigMap. Kubernetes will retry automatically. No special handling is required.
- **ACK controllers required**: Deploying with `provider: ack` requires the ACK RDS controller (`rds.services.k8s.aws`) and ACK EC2 controller (`ec2.services.k8s.aws`) to be installed in the cluster, along with the FieldExport CRD (`services.k8s.aws/FieldExport`).
- **IRSA**: The chart's ServiceAccount will need an IAM role (via IRSA or Pod Identity) with permissions to create and manage RDS and EC2 security group resources. IAM configuration is outside the scope of this chart.
