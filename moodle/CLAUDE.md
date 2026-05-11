# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This file scopes guidance to the **`moodle` Helm chart**. Repo-wide conventions
(CI, `ct lint`, chart-releaser flow, internal `mariadb` dependency pattern)
live in `../CLAUDE.md` — don't duplicate them here.

## Chart-specific commands

```bash
# Refresh the vendored mariadb dependency after editing Chart.yaml
helm dependency update .

# Render with the in-tree defaults (internal mariadb enabled)
helm template release-name . -f values.yaml

# Render against the staging values used in devops repo
helm template release-name . \
  -f ../../devops/configuration/moodle/values_staging.yaml

# Lint just this chart through CI's config
ct lint --config ../.github/ct-lint.yaml --target-branch master --charts moodle
```

The chart bundles `mariadb-*.tgz` under `charts/`; it's the internal UBC
mariadb chart (not Bitnami), aliased as `db` and gated on `db.enabled`.
Disable it and set `externalDatabase.enabled=true` to point at an external
MariaDB / MySQL.

## Architecture

### Single shared container spec
Every Moodle pod (the `Deployment`, the `CronJob` running `cron.php`, and the
init container) renders the same env block via the
**`moodle.app.spec`** template in `templates/_helpers.tpl`. When adding a new
env var or volume mount the app needs, edit `_helpers.tpl` — not the
individual workload files. Volume mounts the workload pods need go through
the matching **`moodle.app.mounts`** helper.

### Database wiring is helper-driven
All workloads (Moodle web, cron, optional `shibd`) read DB connection details
through these helpers, which transparently switch between internal `db.*` and
`externalDatabase.*`:

- `moodle.databaseHost` / `moodle.databasePort` / `moodle.databaseName`
- `moodle.databaseUser` / `moodle.databaseSecretName` / `moodle.databaseSecretKey`
- `moodle.databaseRootSecretName` / `moodle.databaseRootSecretKey`

`moodle.databaseSecretKey` defaults to `password-<username>` when the
internal mariadb chart is in use — that key shape is dictated by the upstream
mariadb chart and must match.

### Optional companion workloads
`templates/deployment.yaml` declares **four** Deployments behind feature
flags, all in one file:

| Flag | What gets deployed | Notes |
|---|---|---|
| (always) | `<release>-moodle` (Apache + PHP) | hostAlias `status.localhost` is required by the `metrics` apache-exporter sidecar |
| `memcached.enabled` | `<release>-memcached` (+ optional exporter) | Internal cluster only; turn off to point at an external memcached |
| `redis.enabled` | `<release>-redis` (+ optional exporter) | Same on/off semantics as memcached |
| `shib.enabled` | `<release>-shibd` | Reuses the moodle DB for ODBC session store via the same DB helpers |

Persistence is **`ReadWriteMany`** because every replica mounts the same
`/moodledata` PVC. Don't switch to RWO unless `replicas` is also forced to 1.

### Cron model
`templates/cronjob.yaml` runs `php admin/cli/cron.php` as `www-data` on the
moodle image, default schedule `*/1 * * * *`, `concurrencyPolicy: Forbid`. It
shares the moodle image, env, and PVC with the web pods — that's why the
cron's container body is just `include "moodle.app.spec"` plus a `command`
override.

### UBC course payments add-on
`ubcCoursePayment.enabled` injects ~15 `MOODLE_UBC_COURSE_PAYMENT_*` env vars
in `_helpers.tpl`. The payment DB is assumed to live **on the same MariaDB
server** as Moodle — only the database name is configurable, credentials are
reused from the moodle DB user.

## Versioning rules for this chart

- `appVersion` in `Chart.yaml` is the Moodle release line (currently 4.5.x);
  it's also used as the default image tag when `image.tag` is unset (see the
  `image:` line in `moodle.app.spec`).
- The deployed image is **`lthub/moodle`**, built from
  `github.com/ubc/moodle-docker`. Tags like `REL1_43_B10` from that repo are
  the expected `image.tag` shape — they don't always match `appVersion`.
- Bumping the `mariadb` sub-chart requires editing **both** `Chart.yaml`'s
  dependency block and re-running `helm dependency update .` so `Chart.lock`
  and `charts/mariadb-*.tgz` stay in sync.
