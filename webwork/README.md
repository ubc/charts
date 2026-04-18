# webwork

A Helm chart to deploy [WeBWorK](https://webwork.maa.org/) — an open-source online homework system — on Kubernetes.

**Chart version:** 0.2.0 | **App version:** 2.18.0

---

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x
- UBC charts repo added:

```bash
helm repo add ubc https://ubc.github.io/charts
helm repo update
```

---

## Installing the chart

```bash
helm install my-webwork ubc/webwork -f values.yaml
```

---

## Database providers

The chart supports three database backends, selected with `db.provider`:

| Value | Description |
|---|---|
| `""` (default) | Auto-detect: `"local"` if `db.enabled: true`, else `"external"` |
| `"local"` | Bundled UBC MariaDB subchart — suitable for development |
| `"ack"` | AWS ACK RDS controller provisions a managed MariaDB instance |
| `"external"` | Externally-managed database — supply host and credentials |

### local — bundled MariaDB

```yaml
db:
  provider: local
  enabled: true        # required to load the mariadb subchart
  auth:
    username: webwork
    database: webwork
    password: changeme
  persistence:
    size: 8Gi
```

### external — bring your own database

```yaml
db:
  provider: external
  auth:
    username: webwork
    database: webwork
    password: changeme
  service:
    name: my-mariadb-host   # hostname or Kubernetes service name
    port: 3306
```

### ack — AWS RDS via ACK controller

Provisions a managed MariaDB RDS instance using [AWS Controllers for Kubernetes](https://aws-controllers-k8s.github.io/community/). Requires the ACK RDS controller (`rds.services.k8s.aws`) and ACK EC2 controller (`ec2.services.k8s.aws`) installed in the cluster.

The chart creates:
- A VPC **SecurityGroup** (port 3306 open to `db.ack.ingressCIDRs`)
- A **DBSubnetGroup** from `db.ack.subnetIDs`
- A **DBInstance** (MariaDB engine)
- Two **FieldExport** resources that populate a ConfigMap with the RDS endpoint and port once provisioning completes

The app Deployment reads `WEBWORK_DB_HOST` and `WEBWORK_DB_PORT` from that ConfigMap via `configMapKeyRef`. Pods will retry connecting until RDS is ready (typically 5–10 minutes after first `helm install`).

**Required values:**

```yaml
db:
  provider: ack
  auth:
    username: webwork
    database: webwork
    password: ""        # auto-generated and stable if left empty
  ack:
    region: us-west-2
    vpcId: vpc-xxxxxxxxxxxxxxxxx          # required
    subnetIDs:                            # required; at least two subnets in different AZs
      - subnet-xxxxxxxxxxxxxxxxx
      - subnet-yyyyyyyyyyyyyyyyy
    ingressCIDRs:
      - 10.0.0.0/8                        # CIDRs allowed to reach RDS on port 3306
    dbInstanceClass: db.t3.medium
    engineVersion: "10.6"
    allocatedStorage: 20
    storageType: gp3
    storageEncrypted: true
    multiAZ: false
```

**IAM (IRSA):** The chart's ServiceAccount needs an IAM role with permissions to manage RDS instances and EC2 security groups. Configure IRSA separately via `serviceAccount.annotations`.

> **Note:** `vpcSecurityGroupRefs` (ACK cross-resource references) requires `rds-controller >= 0.1.x`. If your controller version does not support it, provision the SecurityGroup separately and supply the SG ID directly using `vpcSecurityGroupIDs` in a values override.

---

## Configuration reference

### Core

| Parameter | Description | Default |
|---|---|---|
| `replicaCount` | Number of webwork replicas | `1` |
| `image.repository` | Container image | `lthub/webwork` |
| `image.tag` | Image tag (defaults to appVersion) | `""` |
| `rootUrl` | Public URL of the webwork instance | `http://localhost` |
| `timezone` | Application timezone | `America/Vancouver` |
| `secret` | Mojolicious secret passphrase (auto-generated if empty) | `""` |
| `supportEmail` | Support email shown to users | `support@example.edu` |
| `maxRequestSize` | File upload limit in bytes | `1342177280` (1.25 GiB) |

### SMTP

| Parameter | Description | Default |
|---|---|---|
| `smtp.server` | SMTP server hostname | `localhost` |
| `smtp.sender` | From address | `no-reply@example.com` |

### Service and Ingress

| Parameter | Description | Default |
|---|---|---|
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `service.annotations` | Service annotations (e.g. AWS NLB) | `{}` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | IngressClass name | `""` |
| `ingress.hosts` | Ingress host rules | `[chart-example.local]` |
| `ingress.tls` | TLS configuration | `[]` |

### Persistence

Five volumes can be persisted independently. All default to `emptyDir` (data lost on pod restart).

| Parameter | Mount path | Default size |
|---|---|---|
| `coursePersistence` | `/opt/webwork/courses` | `8Gi` |
| `libraryPersistence` | `/opt/webwork/libraries` | `8Gi` |
| `htdocsTmpPersistence` | `/opt/webwork/webwork2/htdocs/tmp` | `8Gi` |
| `htdocsDataPersistence` | `/opt/webwork/webwork2/htdocs/DATA` | `8Gi` |
| `logsPersistence` | `/opt/webwork/webwork2/logs` | `8Gi` |

Set `enabled: true` and configure `storageClass`, `accessMode`, and `size` for each as needed.

### Database (`db`)

| Parameter | Description | Default |
|---|---|---|
| `db.provider` | Database backend: `""`, `"local"`, `"ack"`, `"external"` | `""` |
| `db.enabled` | Load bundled MariaDB subchart (required for `provider: local`) | `false` |
| `db.auth.username` | Database username | `webwork` |
| `db.auth.database` | Database name | `webwork` |
| `db.auth.password` | Database password (auto-generated if empty for local/ack) | `randompassword` |
| `db.service.port` | Database port (local/external) | `3306` |
| `db.service.name` | External database hostname | `""` |
| `db.architecture` | MariaDB architecture: `standalone` or `replication` | `standalone` |
| `db.persistence.size` | MariaDB PVC size (local only) | `8Gi` |

#### ACK-specific (`db.ack`)

| Parameter | Description | Default |
|---|---|---|
| `db.ack.region` | AWS region | `us-west-2` |
| `db.ack.dbInstanceClass` | RDS instance class | `db.t3.medium` |
| `db.ack.engineVersion` | MariaDB engine version | `"10.6"` |
| `db.ack.allocatedStorage` | Storage in GiB | `20` |
| `db.ack.storageType` | Storage type | `gp3` |
| `db.ack.storageEncrypted` | Encrypt storage at rest | `true` |
| `db.ack.multiAZ` | Enable Multi-AZ (recommended for production) | `false` |
| `db.ack.vpcId` | VPC ID for SecurityGroup (**required**) | `""` |
| `db.ack.subnetIDs` | Subnet IDs for DBSubnetGroup (**required**, min 2) | `[]` |
| `db.ack.ingressCIDRs` | CIDRs allowed on port 3306 | `[10.0.0.0/8]` |

### Workers

| Parameter | Description | Default |
|---|---|---|
| `worker.lti1p3.enabled` | Enable LTI 1.3 background worker | `true` |
| `worker.lti1p3.replicaCount` | LTI worker replicas | `1` |
| `worker.mojo.enabled` | Enable Mojolicious Minion worker | `true` |
| `worker.mojo.replicaCount` | Mojo worker replicas | `1` |

### Cronjobs

| Parameter | Description | Default |
|---|---|---|
| `cronjob.lti_update_classlist.enabled` | Sync LTI class lists daily | `true` |
| `cronjob.lti_update_classlist.schedule` | Cron schedule | `0 11 * * *` |
| `cronjob.lti_update_grades.enabled` | Sync LTI grades daily | `true` |
| `cronjob.lti_update_grades.schedule` | Cron schedule | `0 13 * * *` |

### R server (`r`)

| Parameter | Description | Default |
|---|---|---|
| `r.enabled` | Deploy RServe for R problem rendering | `true` |
| `r.image.repository` | RServe image | `ubcctlt/rserve` |
| `r.replicas` | RServe replicas | `1` |

### Shibboleth (`shibd`)

| Parameter | Description | Default |
|---|---|---|
| `shibd.enabled` | Deploy Shibboleth SP sidecar | `false` |
| `shibd.idp.discovery_url` | IdP discovery URL | — |
| `shibd.idp.metadata_url` | IdP metadata URL | — |
| `shibd.sp.entity_id` | SP entity ID | — |

---

## LTI 1.3

Configure LTI clients under `ltiClient` (list). Each entry requires:

```yaml
ltiClient:
- client_id: <canvas-client-id>
  platform_id: https://canvas.example.com
  oauth2_access_token_url: https://canvas.example.com/login/oauth2/token
  oidc_auth_url: https://canvas.example.com/api/lti/authorize_redirect
  platform_security_jwks_url: https://canvas.example.com/api/lti/security/jwks
  tool_public_key: |
    -----BEGIN PUBLIC KEY-----
    ...
    -----END PUBLIC KEY-----
  tool_private_key: |
    -----BEGIN RSA PRIVATE KEY-----
    ...
    -----END RSA PRIVATE KEY-----
```

---

## Upgrading

### 0.1.x → 0.2.0

No values changes required for existing deployments. The new `db.provider` field defaults to `""` which auto-detects from `db.enabled`, preserving existing behavior exactly.

To explicitly opt in to the new provider names:
- Replace `db.enabled: true` with `db.provider: local` + `db.enabled: true`
- Replace `db.enabled: false` (external DB) with `db.provider: external`
