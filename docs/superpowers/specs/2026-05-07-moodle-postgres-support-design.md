# moodle: Postgres support via zalando postgres-operator

**Date:** 2026-05-07
**Chart:** `moodle/`
**Status:** Approved

## Overview

Add Postgres as a supported database engine for the `moodle` chart, alongside
the existing internal-MariaDB and external-MariaDB paths. Postgres is
provisioned by populating a `postgresql.acid.zalan.do/v1` custom resource
consumed by a cluster-wide [zalando postgres-operator]; the chart does not
install or manage the operator itself.

Engine selection is exposed as a single `db.type: mariadb|postgres` knob.
MariaDB stays the default. Existing values files render unchanged.

[zalando postgres-operator]: https://github.com/zalando/postgres-operator

## Goals

- Let users deploy Moodle on Postgres by setting `db.type: postgres` and
  letting the chart render the operator CR.
- Keep MariaDB the default and preserve runtime behavior for the common case
  (`db.enabled: true` with the bundled mariadb subchart). One-line values
  edit required for users currently running external mariadb — see
  "Backwards Compatibility".
- Make the engine switch the only public knob users normally touch — branch
  internally on `db.type` for host, port, env vars, secret name/key.
- Symmetric `externalDatabase` support: external mode works for both
  engines (cloud-managed Postgres like RDS / Cloud SQL, in addition to the
  existing external MariaDB path). The engine is still `db.type` — there is
  no separate `externalDatabase.type` field.

## Non-Goals

- Installing or upgrading the postgres-operator. Operator is assumed to be
  pre-installed cluster-wide.
- Cross-engine data migration (mariadb → postgres). Fresh installs only.
- Postgres support for the optional `shibd` Deployment (`shib.enabled: true`).
  ODBC driver/library wiring would change; deferred to a follow-up if needed.
  The validation guard rejects `shib.enabled: true` + `db.type: postgres`.
- Bundling postgres-operator as a subchart.
- Read-replica routing inside Moodle (zalando exposes `<cluster>-repl`; the
  Moodle app would need code-level changes to use it).
- Backup/restore of Postgres beyond passing operator-native WAL-G env vars
  through. No CronJob-style backup like the mariadb chart has.

## Values Surface

```yaml
db:
  enabled: true               # provision DB through the chart (vs externalDatabase)
  type: mariadb               # mariadb | postgres
  architecture: standalone    # mariadb-only; ignored when type=postgres

  # Gates the bundled mariadb subchart via Chart.yaml condition.
  # Must be:
  #   true  when db.enabled=true AND db.type=mariadb (default common case)
  #   false when db.type=postgres
  #   false when db.enabled=false + externalDatabase.enabled=true
  #         (external-mariadb users must set this explicitly when upgrading)
  # The validation guard rejects mismatches at template time.
  mariadb:
    enabled: true

  # Existing mariadb config (unchanged). The `db.db.type` field becomes
  # informational/deprecated for one minor version; engine selection now
  # comes from `db.type` via the `moodle.dbDialect` helper.
  db:
    type: mariadb
  auth:
    database: moodle
    username: moodle
    # rootPassword, existingSecret, userPasswordKey ... (unchanged)

  postgres:
    teamId: ctlt              # zalando requires teamId; clusterName must start with it
    clusterName: ""           # default: "<teamId>-<release>-moodle"
    numberOfInstances: 2
    version: "16"

    resources:
      requests: { cpu: 200m, memory: 512Mi }
      limits:   { cpu: 1,    memory: 1Gi }
    tolerations: []
    nodeAffinity: {}

    volume:
      size: 10Gi
      storageClass: ""

    database: moodle           # database name created by the operator
    username: moodle           # role created with LOGIN; password is operator-generated

    backup:
      enabled: false
      s3Bucket: ""
      s3Region: ""
      s3Endpoint: ""
      retentionDays: 7

    # Deep-merged into the rendered CR `spec:` so users can set obscure
    # operator fields without chart upgrades.
    extraManifest: {}

externalDatabase:
  enabled: false
  # Engine is read from `db.type` above; no separate field here.
  port:                        # default: 3306 (when db.type=mariadb) or 5432 (when db.type=postgres)
  database: moodle
  user: moodle
  password:
  existingSecret:
  service:
    enabled: true
    externalName: ""
    port:                      # same default rule as above
```

### Contract notes

- `db.type` is the single engine selector. Helpers, env wiring, and rendered
  manifests all branch on it.
- `db.mariadb.enabled` is a new boolean that gates the bundled mariadb
  subchart. It must be explicitly set to `false` in two situations because
  Helm subchart `condition:` cannot read `db.type` (it only supports boolean
  field references):
  - When switching to postgres (`db.type: postgres`).
  - When using **external** mariadb (`db.enabled: false` +
    `externalDatabase.enabled: true` + `externalDatabase.type: mariadb`),
    since today's users only set `db.enabled: false` and the new
    `db.mariadb.enabled: true` default would otherwise re-enable the
    subchart.

  Default stays `true` so the common internal-mariadb case (`db.enabled:
  true`, `db.type: mariadb`) upgrades without edits. The validation guard
  fails fast on every inconsistent combination.
- `db.postgres.username` is the role Moodle authenticates as. The operator
  generates its password into a Kubernetes Secret following its fixed naming
  convention (see "Credential flow" below). The chart never sees the password.
- The external path (`externalDatabase.enabled: true`) reuses `db.type` to
  choose dialect and default port — no parallel field. Mutual exclusion with
  `db.enabled` is enforced by the validation guard.
- `db.postgres.extraManifest` is an escape hatch (deep-merged into the
  rendered CR's `spec:`).

## Manifest Layout

Files added or changed in `moodle/`:

```
Chart.yaml
  dependencies:
    - name: mariadb
      condition: db.mariadb.enabled    # CHANGED from db.enabled
      version: "*"
      alias: db
      repository: https://ubc.github.io/charts
      tags: [moodle-database]

templates/
  postgresql.yaml          # NEW — renders the postgresql.acid.zalan.do CR
                           # gated on: .Values.db.enabled AND eq .Values.db.type "postgres"
  _validate.tpl            # NEW — fail-fast guards (see "Validation")
  _helpers.tpl             # CHANGED — database* helpers branch on db.type;
                           #           new moodle.dbDialect helper
  deployment.yaml          # unchanged (still pulls env via moodle.app.spec)
  cronjob.yaml             # unchanged
  service.yaml             # unchanged for moodle; externalDatabase ExternalName
                           # picks default port from db.type (3306 or 5432)

NOTES.txt                  # CHANGED — print connection details by engine
README.md                  # CHANGED — document db.type + postgres values

values_postgres.yaml.example  # NEW (top-level) — minimal known-good postgres values
                              # for ops/CI consumption
```

### Postgres CR template (sketch)

```yaml
{{- if and .Values.db.enabled (eq .Values.db.type "postgres") -}}
{{- include "moodle.validateDb" . -}}
{{- $clusterName := default
      (printf "%s-%s-moodle" .Values.db.postgres.teamId .Release.Name)
      .Values.db.postgres.clusterName -}}
apiVersion: acid.zalan.do/v1
kind: postgresql
metadata:
  name: {{ $clusterName }}
  labels:
    {{- include "moodle.labels" . | nindent 4 }}
    tier: db
spec:
  teamId: {{ .Values.db.postgres.teamId | quote }}
  postgresql:
    version: {{ .Values.db.postgres.version | quote }}
  numberOfInstances: {{ .Values.db.postgres.numberOfInstances }}
  volume:
    size: {{ .Values.db.postgres.volume.size }}
    {{- with .Values.db.postgres.volume.storageClass }}
    storageClass: {{ . }}
    {{- end }}
  databases:
    {{ .Values.db.postgres.database }}: {{ .Values.db.postgres.username }}
  users:
    {{ .Values.db.postgres.username }}: []   # plain LOGIN role; owns the moodle db
  resources:
    {{- toYaml .Values.db.postgres.resources | nindent 4 }}
  {{- with .Values.db.postgres.tolerations }}
  tolerations: {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if .Values.db.postgres.backup.enabled }}
  env:
    - name: WAL_S3_BUCKET
      value: {{ .Values.db.postgres.backup.s3Bucket | quote }}
    - name: AWS_REGION
      value: {{ .Values.db.postgres.backup.s3Region | quote }}
    {{- with .Values.db.postgres.backup.s3Endpoint }}
    - name: AWS_ENDPOINT
      value: {{ . | quote }}
    {{- end }}
  {{- end }}
  {{- with .Values.db.postgres.extraManifest }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
```

AWS credentials for WAL-G are expected to reach the postgres pods through
operator-level config (IRSA, pod identity, or operator env). Out of scope
for this chart.

## Helpers (`_helpers.tpl`)

Branching matrix for the `moodle.database*` helpers, which every workload
(Moodle web, cron, optional shibd) reads through:

| Helper | `db.type=mariadb` (internal) | `db.type=postgres` (internal) | external (engine still read from `db.type`) |
|---|---|---|---|
| `moodle.databaseHost` | `<release>-mariadb` (or `-primary` for replication) — unchanged | `<clusterName>` (master service name) | `moodle.externalDatabaseName` ExternalName service — unchanged |
| `moodle.databasePort` | `3306` | `5432` | `externalDatabase.port` if set, else `3306`/`5432` by `db.type` |
| `moodle.databaseName` | `db.auth.database` — unchanged | `db.postgres.database` | `externalDatabase.database` — unchanged |
| `moodle.databaseUser` | `db.auth.username` — unchanged | `db.postgres.username` | `externalDatabase.user` — unchanged |
| `moodle.databaseSecretName` | `<mariadb>-user-password` — unchanged | `<username>.<clusterName>.credentials.postgresql.acid.zalan.do` | `externalDatabase.existingSecret` or chart-rendered secret — unchanged |
| `moodle.databaseSecretKey` | `password-<user>` — unchanged | `password` (operator's fixed key shape) | `db_password` — unchanged |
| `moodle.databaseRootSecretName` / `Key` | unchanged | `""` (Moodle never needs root for postgres; callers already gate on its presence) | unchanged |

New helper:

```gotpl
{{- define "moodle.dbDialect" -}}
{{- if eq .Values.db.type "postgres" -}}pgsql
{{- else -}}{{- default "mariadb" .Values.db.db.type -}}
{{- end -}}
{{- end -}}
```

`moodle.app.spec` switches the `MOODLE_DB_TYPE` env from
`default "mariadb" .Values.db.db.type` to
`include "moodle.dbDialect" .`. The exact string `pgsql` is the documented
value the upstream `lthub/moodle` image expects; will be confirmed against
`github.com/ubc/moodle-docker` during implementation.

## Credential Flow (postgres internal)

1. User sets `db.postgres.username: moodle`, `db.postgres.database: moodle`.
2. The chart renders the `postgresql` CR. The zalando operator reconciles it
   and creates a per-role secret named
   `moodle.<clusterName>.credentials.postgresql.acid.zalan.do` containing
   `username` and `password` keys.
3. Moodle Deployment + CronJob reference `MOODLE_DB_PASSWORD` via
   `secretKeyRef` to that secret, key `password`.
4. Moodle pods stay un-ready until the operator finishes reconciling. The
   existing `livenessProbe.initialDelaySeconds: 600` and the readiness
   probe's retry budget cover the operator's reconcile window.
5. The chart never sees the password and never writes it to its own Secret.
   The operator owns the credential lifecycle.

For external Postgres (`externalDatabase.enabled: true` +
`externalDatabase.type: postgres`), the existing
`templates/secrets.yaml` `db_password` branch handles it identically to
external mariadb — only the port default differs.

## Validation Guard (`templates/_validate.tpl`)

Renders nothing; runs as `{{- include "moodle.validateDb" . -}}` from a
file that always renders (top of `templates/deployment.yaml` and
`templates/postgresql.yaml`) so misconfigs fail at `helm template` /
`helm install` time, not at pod startup.

```gotpl
{{- define "moodle.validateDb" -}}
{{- if and .Values.db.enabled (eq .Values.db.type "postgres") .Values.db.mariadb.enabled -}}
{{ fail "db.type=postgres requires db.mariadb.enabled=false (the bundled mariadb subchart must be disabled)" }}
{{- end -}}
{{- if and .Values.db.enabled (eq .Values.db.type "mariadb") (not .Values.db.mariadb.enabled) -}}
{{ fail "db.type=mariadb requires db.mariadb.enabled=true" }}
{{- end -}}
{{- if not (or (eq .Values.db.type "mariadb") (eq .Values.db.type "postgres")) -}}
{{ fail (printf "db.type must be \"mariadb\" or \"postgres\", got %q" .Values.db.type) }}
{{- end -}}
{{- if and .Values.db.enabled .Values.externalDatabase.enabled -}}
{{ fail "db.enabled and externalDatabase.enabled are mutually exclusive" }}
{{- end -}}
{{- if and (not .Values.db.enabled) .Values.externalDatabase.enabled .Values.db.mariadb.enabled -}}
{{ fail "externalDatabase.enabled=true requires db.mariadb.enabled=false (the bundled mariadb subchart must be disabled)" }}
{{- end -}}
{{- if and .Values.shib.enabled (eq (include "moodle.dbDialect" .) "pgsql") -}}
{{ fail "shib.enabled=true is not supported with postgres in this chart version" }}
{{- end -}}
{{- end -}}
```

## Backup Story

- **MariaDB path:** unchanged. The mariadb subchart's `backup.yaml` /
  `physicalbackup.yaml` continue to render when `db.type: mariadb`.
- **Postgres path:** continuous WAL archiving via the operator. `db.postgres.backup.*`
  is passed through to the CR's `spec.env`. Default `enabled: false`, with
  README and NOTES.txt calling out that no backups run until users opt in
  and provide S3 details + cluster-level AWS auth.
- **External Postgres:** out of scope; users own backups.

## External Postgres

- `externalDatabase.enabled: true` with `db.type: postgres` works the same
  way external-mariadb works today.
- The chart still renders an `ExternalName` Service so Moodle pods talk to a
  stable in-cluster name.
- `externalDatabase.port` defaults to `5432` when `db.type: postgres` and
  unset; `3306` when `db.type: mariadb`.
- `externalDatabase.existingSecret` is the recommended way to hand in the
  password; chart-rendered fallback Secret keeps key name `db_password`.
- `MOODLE_DB_TYPE` follows `db.type` (`moodle.dbDialect` reads it directly).

## Backwards Compatibility

1. **Subchart condition rename**: `Chart.yaml` flips
   `condition: db.enabled` → `condition: db.mariadb.enabled`. New default
   `db.mariadb.enabled: true` in `values.yaml`.
   - Existing values files that set `db.enabled: true` (internal mariadb,
     the common case) keep working with no edits — the new default carries
     them.
   - **Existing values files that set `db.enabled: false` to use external
     mariadb require a one-line edit**: add `db.mariadb.enabled: false` so
     the subchart stops rendering. Without this edit the chart now renders
     both an unwanted mariadb StatefulSet AND the external pointer. The
     validation guard fails the install at template time with an actionable
     message instead of letting it proceed silently.
   - The chart's `CHANGELOG`/release notes (and `NOTES.txt` for the first
     install) call this out, and the implementation plan must update
     `devops/configuration/moodle/values_staging.yaml` (and any other
     external-mariadb consumers in this repo's sister projects) in the same
     PR series.
2. **`db.db.type` semantic narrowing**: today this field flows directly into
   `MOODLE_DB_TYPE`. After this change, the dialect comes from
   `moodle.dbDialect` (which reads `db.type` and ignores `db.db.type` for
   engine selection). Documented as deprecated in `values.yaml` and
   `README.md`; left in place for one chart minor version, then removed.
   No runtime behavior change for the `mariadb` default.
3. **Chart version bump**: `0.2.15` → `0.3.0`. Minor bump because of the new
   `db.type` / `db.postgres` surface and the subchart-condition rename.
   Not major because existing values files render identically.

## Testing Strategy

Three layers, ordered by cost:

1. **`helm lint` + `helm template` matrix** (cheapest, runs in CI via
   `.github/workflows/lint-charts.yaml`):
   - Default values (`db.type=mariadb`, internal): no postgresql CR rendered;
     mariadb subchart present.
   - `db.type=postgres`, `db.mariadb.enabled=false`: postgresql CR rendered
     with expected name; no mariadb StatefulSet; env block uses operator-secret
     reference; `MOODLE_DB_TYPE` is `pgsql`.
   - `db.type=postgres`, `db.enabled=false`, `externalDatabase.enabled=true`,
     `db.mariadb.enabled=false`: ExternalName Service on port 5432; no
     postgresql CR; `MOODLE_DB_TYPE` is `pgsql`.
   - Mismatch combos fail with the guard message:
     - `db.type=postgres + db.mariadb.enabled=true`
     - `db.type=mariadb + db.mariadb.enabled=false`
     - `db.enabled=true + externalDatabase.enabled=true`
     - `db.enabled=false + externalDatabase.enabled=true + db.mariadb.enabled=true`
     - `db.type=banana`
     - `shib.enabled=true + db.type=postgres`

2. **Render goldens**: snapshot the rendered postgresql CR for the default
   postgres values into `tests/postgres-cr.golden.yaml`. CI diff catches
   accidental schema drift. New for this chart but trivial — shell script +
   `helm template | diff`.

3. **Live integration** (manual, not in CI): one-shot `helm install` against
   a kind cluster with the zalando operator pre-installed; verify Moodle
   reaches the login page on a fresh postgres-backed install. Documented
   below as the implementation acceptance test.

## Acceptance Criteria

- `helm template` of the chart with **unmodified** existing devops staging
  values (`devops/configuration/moodle/values_staging.yaml`) produces a diff
  limited to label/annotation noise — no removed resources, no env-block
  changes for the mariadb path.
- `helm template` with `db.type: postgres` and the example postgres values
  produces exactly one `postgresql.acid.zalan.do` CR, no mariadb workload, a
  Moodle Deployment whose `MOODLE_DB_*` env block resolves at runtime from
  the operator-generated secret name pattern.
- All six guard misconfigs fail `helm template` with the expected message.
- Live install on kind with the zalando operator pre-installed reaches a
  fresh Moodle login page using Postgres.

## Open Questions Deferred to Implementation

- Exact string the `lthub/moodle` image expects for postgres (`pgsql` vs
  other) — confirm against `github.com/ubc/moodle-docker` env handling.
- Default `db.postgres.users` flags — the sketch shows `[]` (plain LOGIN role
  owning its database). Confirm against the operator's behavior for empty
  flag arrays vs explicit `["createdb"]`.
- Whether to wire `db.postgres.tolerations` and `nodeAffinity` through to
  the CR via the operator's pass-through fields or via `extraManifest`.
  Default position: dedicated fields for the common case, `extraManifest`
  for the long tail.
