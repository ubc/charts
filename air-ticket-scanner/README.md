# air-ticket-scanner

A Helm chart that runs the **air-ticket-scanner** as a Kubernetes `CronJob`: it
queries ServiceNow on a schedule, filters incidents against alert criteria, and
emails a summary.

Credentials are never stored in this chart. Sensitive values are pulled at runtime
from a secrets manager via the [External Secrets Operator][eso]; all
environment-specific and internal values are supplied by a private per-env values
file, not by the defaults here.

## Prerequisites

- Kubernetes with the [External Secrets Operator][eso] installed.
- An External Secrets store in the cluster that can read your secrets backend.
  Reference its name and kind via `externalSecrets.secretStoreRef` in your values file.
- An image pull secret in the target namespace if the image registry is private;
  set its name via `imagePullSecrets`.

## Usage

Supply a private values file with your environment-specific settings and install:

```bash
helm upgrade --install air-ticket-scanner . \
  -n <namespace> --create-namespace \
  -f my-values.yaml
```

The chart is typically deployed by a GitOps controller that merges the
chart with a values file kept in a private config repository.

## Values

| Key | Description | Default |
|-----|-------------|---------|
| `env` | Environment name; used for labels. | `""` |
| `image.repository` | Container image repository. Set per env. | generic placeholder |
| `image.tag` | Image tag. Set per env to an immutable tag. | `latest` |
| `image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `imagePullSecrets` | Pull secrets for a private registry. | `[]` |
| `schedule` | CronJob schedule. | `*/15 * * * *` |
| `concurrencyPolicy` | CronJob concurrency policy. | `Forbid` |
| `successfulJobsHistoryLimit` | Kept successful jobs. | `3` |
| `failedJobsHistoryLimit` | Kept failed jobs. | `1` |
| `backoffLimit` | Job retries within a run. | `0` |
| `serviceAccount.name` | ServiceAccount name. | `air-ticket-scanner` |
| `resources` | Container resource requests/limits. | see `values.yaml` |
| `externalSecrets.secretStoreRef.name` | Name of your External Secrets store. Set per env. | generic placeholder |
| `externalSecrets.secretStoreRef.kind` | Kind of your External Secrets store. Set per env. | `SecretStore` |
| `externalSecrets.refreshInterval` | How often to re-sync secrets. | `24h` |
| `externalSecrets.servicenow.path` | Backend path holding the ServiceNow creds. Set per env. | generic placeholder |
| `externalSecrets.servicenow.usernameProperty` | Field name for the username. | `username` |
| `externalSecrets.servicenow.passwordProperty` | Field name for the password. | `password` |
| `config` | Non-sensitive env vars injected via a ConfigMap. | empty; set per env |

## How configuration reaches the container

| Source | Values |
|--------|--------|
| Secrets backend → ExternalSecret → Secret | ServiceNow username & password |
| `config` → ConfigMap | ServiceNow instance URL, SMTP host/port, alert from/to, ticket prefix, company |

All required variables must resolve at startup or the job fails fast.

[eso]: https://external-secrets.io/
