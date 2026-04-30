# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Scope

Helm chart for the UBC CTLT MediaWiki deployment. Image is `ubcctlt/mediawiki` (built from https://github.com/ubc/mediawiki-docker), not upstream MediaWiki. The chart wraps a wiki pod plus several optional sidecar deployments. Parent repo guidance lives in `../CLAUDE.md`.

## Common Commands

```bash
# From the chart directory
helm dependency update .                    # pull bitnami/mariadb tarball into charts/
helm lint .
helm template my-wiki . -f values.yaml      # dry-render

# Lint as CI does (run from repo root)
ct lint --config .github/ct-lint.yaml --target-branch master --charts mediawiki

# Bump appVersion when ubcctlt/mediawiki image is updated; bump version on every change
```

## Chart Architecture

### Database dependency is the internal UBC mariadb chart
`mediawiki` depends on the internal `mariadb` chart at `https://ubc.github.io/charts` (operator-driven, see `../mariadb`), aliased as `db`, gated by `db.enabled`. The subchart provisions a `MariaDB` CR plus `Database`/`User`/`Grant` resources from `db.auth.database` and `db.auth.username`; the operator generates the user password into the secret `<release>-db-user-password` under key `password-<username>`. To target an externally managed database instead, set `db.enabled=false` and configure `externalDatabase.*`.

### Container env is built once and reused
`templates/_helpers.tpl` defines `mediawiki.app.spec` — a single block of `image`, `env`, and `volumeMounts` consumed by both the main `Deployment` and the optional `jobrunner` `Deployment`. When adding a new env var or volume, edit the helper, not individual deployments. `mediawiki.app.mounts` plays the same role for `volumes`.

### One chart, multiple deployments
`templates/deployment.yaml` emits up to four deployments via `{{- if }}` gates, all in one file:
- main wiki (always)
- `-node-services` (`node_services.enabled`) — parsoid:8142 + restbase:7231 in one container; URLs are wired into the wiki pod via `PARSOID_URL` / `RESTBASE_URL`
- `-memcached` (`memcached.enabled`) — optional sidecar deployment with an optional Prometheus exporter container in the same pod
- `-jobrunner` (`jobrunner.enabled`) — reuses `mediawiki.app.spec` but overrides `args` to run `runJobs.php --wait`

`templates/deployment-simplesamlphp.yaml` is a separate file for the SAML SP. It expects a **shared RWX volume** (`simplesamlphp-code`, claim `*-simplesamlphp-pvc`) so the wiki pod can read SimpleSAMLphp source written by the SP pod — the SP cert/key are mounted via `subPath` because symlinks break across the NFS share.

### Secret resolution for the DB password
DB connection details flow through the `mediawiki.db.*` helpers in `_helpers.tpl`:
- `mediawiki.db.host` — `<release>-db` (standalone) or `<release>-db-primary` (replication) when `db.enabled`; otherwise `externalDatabase.host`.
- `mediawiki.db.passwordSecretName` / `mediawiki.db.passwordSecretKey` — when `db.enabled`, point at the operator-generated `<release>-db-user-password`/`password-<username>` (or honour `db.auth.existingSecret`/`db.auth.userPasswordKey`); when external, prefer `externalDatabase.existingSecret`/`existingSecretPasswordKey` and otherwise fall back to a chart-owned secret with key `db_password` populated from `externalDatabase.password`.

When changing how DB credentials flow, update the helpers in one place and the templates pick it up.

### Cache backend selection
`mainCache` (default `CACHE_NONE`) is the MediaWiki `$wgMainCacheType`. Enabling `memcached.enabled` adds `MEDIAWIKI_MEMCACHED_SERVERS` pointing at the in-chart memcached service. Enabling `redis.enabled` adds the Redis env block. They are not mutually exclusive at the chart level — picking the right `mainCache` value is the operator's responsibility.

### Custom MediaWiki PHP via ConfigMap
`mediawikiFiles` in `values.yaml` is rendered into a ConfigMap and mounted at `/conf` inside the container (see `mediawiki.app.spec` `volumeMounts`). The default ships an empty `CustomSettings.php`. Anything that needs to land as a file inside the wiki container should go through this map, not a new template.

### Ingress host drives `MEDIAWIKI_SITE_SERVER`
`ingress.hosts[0]` is the canonical hostname; it is also threaded into `MEDIAWIKI_SITE_SERVER` and the SimpleSAMLphp baseurl helpers. Setting hosts to an empty list will produce `https:///...` URLs — keep at least one host configured for any real deploy.

## Versioning Notes

- `Chart.yaml` `version` must be bumped on any change for `chart-releaser-action` to publish.
- `appVersion` tracks the upstream MediaWiki version baked into `ubcctlt/mediawiki` and is used as the default container tag (`image.tag` overrides).
- The Bitnami `mariadb` dependency is pinned to `22.x.x` major; updating across majors usually requires re-checking the `auth.*` and `master.persistence.*` paths used in `values.yaml`.
