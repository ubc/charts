# moodle: Postgres Support via Zalando postgres-operator — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `db.type: mariadb|postgres` to the moodle chart. The postgres path renders a `postgresql.acid.zalan.do/v1` custom resource consumed by a pre-installed [zalando postgres-operator]. MariaDB stays the default.

**Architecture:** A new `db.type` field drives engine selection. Database connection helpers in `_helpers.tpl` branch on `db.type` for host/port/secret name/secret key. A new `moodle.dbDialect` helper sets `MOODLE_DB_TYPE` to `mariadb` or `pgsql`. A new `_validate.tpl` enforces six mutually-consistent invariants and fails `helm template` early with actionable messages. The bundled mariadb subchart's `condition` flips from `db.enabled` to a new `db.mariadb.enabled` so it can be skipped while still letting the chart provision a DB via postgres-operator.

**Tech Stack:** Helm 3, zalando postgres-operator (`acid.zalan.do/v1`), the existing UBC `mariadb` chart subchart, `yq` v4 (mikefarah) for render assertions, `bash` for the test runner. CI: existing `helm/chart-testing-action` plus a new render-assertions step.

[zalando postgres-operator]: https://github.com/zalando/postgres-operator

**Spec:** `docs/superpowers/specs/2026-05-07-moodle-postgres-support-design.md`

---

## File Map

**Create:**
- `moodle/templates/postgresql.yaml` — renders the `postgresql.acid.zalan.do` CR when `db.enabled && db.type == "postgres"`
- `moodle/templates/_validate.tpl` — `moodle.validateDb` partial that runs all guard `fail` rules
- `moodle/values_postgres.yaml.example` — minimal known-good values for installing on postgres
- `moodle/tests/run.sh` — bash test runner with `helm template` + `yq` assertions
- `moodle/tests/lib.sh` — shared assertion helpers (`assert_renders`, `assert_fails_with`, `assert_yq`)
- `moodle/tests/values/internal-mariadb.yaml` — default scenario (no overrides; documents intent)
- `moodle/tests/values/internal-postgres.yaml` — `db.type: postgres + db.mariadb.enabled: false`
- `moodle/tests/values/external-mariadb.yaml` — `db.enabled: false + externalDatabase.enabled + db.mariadb.enabled: false`
- `moodle/tests/values/external-postgres.yaml` — same plus `db.type: postgres`
- `moodle/tests/values/invalid-postgres-mariadb-on.yaml`
- `moodle/tests/values/invalid-mariadb-mariadb-off.yaml`
- `moodle/tests/values/invalid-both-enabled.yaml`
- `moodle/tests/values/invalid-external-mariadb-still-on.yaml`
- `moodle/tests/values/invalid-bad-type.yaml`
- `moodle/tests/values/invalid-shib-postgres.yaml`

**Modify:**
- `moodle/Chart.yaml` — bump `version` `0.2.15` → `0.3.0`; flip dependency `condition: db.enabled` → `condition: db.mariadb.enabled`
- `moodle/values.yaml` — add `db.type`, `db.mariadb.enabled`, `db.postgres.*`; doc-deprecate `db.db.type`
- `moodle/templates/_helpers.tpl` — add `moodle.dbDialect`; branch `moodle.databaseHost`, `moodle.databasePort`, `moodle.databaseName`, `moodle.databaseUser`, `moodle.databaseSecretName`, `moodle.databaseSecretKey` on `db.type`; replace `MOODLE_DB_TYPE` env-value source with `moodle.dbDialect`
- `moodle/templates/deployment.yaml` — include `moodle.validateDb` once at top
- `moodle/templates/service.yaml` — make external-DB ExternalName port follow `db.type` when `externalDatabase.port` is unset
- `moodle/templates/NOTES.txt` — branch the printed connection details on `db.type`
- `moodle/README.md` — document `db.type`, postgres values, and the upgrade note for external-mariadb users
- `.github/workflows/lint-charts.yaml` — add a step that runs `moodle/tests/run.sh` after `ct lint`

**Outside this chart (separate PRs, called out for the implementer):**
- `devops/configuration/moodle/values_*.yaml` — only requires edits if any file sets `db.enabled: false`. Verified at plan-write time: all known files use `db.enabled: true`, so no edit is required today. Re-verify in Task 11.

---

## Task 1: Test harness scaffold

**Goal:** Create the bash test runner so every later task can write tests first. Runner exits 0 with "no tests registered" until tasks add cases.

**Files:**
- Create: `moodle/tests/run.sh`
- Create: `moodle/tests/lib.sh`

- [ ] **Step 1: Write the runner**

Create `moodle/tests/run.sh`:

```bash
#!/usr/bin/env bash
# Render-assertions for the moodle chart.
# Requires: helm 3, yq v4 (mikefarah).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
CHART="$HERE/.."

# shellcheck source=lib.sh
source "$HERE/lib.sh"

PASS=0
FAIL=0

# === Render tests ===
# Added by later tasks. Example:
#   assert_renders "default mariadb" "$HERE/values/internal-mariadb.yaml"

# === yq assertions ===
# Added by later tasks. Example:
#   assert_yq "default MOODLE_DB_TYPE=mariadb" \
#     "$HERE/values/internal-mariadb.yaml" \
#     '... | select(.kind == "Deployment" and .metadata.labels.tier == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_TYPE") | .value' \
#     "mariadb"

# === Guard tests ===
# Added by later tasks. Example:
#   assert_fails_with "postgres + mariadb on" \
#     "$HERE/values/invalid-postgres-mariadb-on.yaml" \
#     "db.type=postgres requires db.mariadb.enabled=false"

if (( FAIL > 0 )); then
  echo
  echo "FAILED $FAIL  PASSED $PASS"
  exit 1
fi
echo
echo "PASSED $PASS  (no failures)"
```

- [ ] **Step 2: Write the assertion helpers**

Create `moodle/tests/lib.sh`:

```bash
# Shared assertion helpers for moodle/tests/run.sh.
# Variables PASS / FAIL come from the caller.

# All assertions use a fixed release name so expected values stay stable.
RELEASE="${RELEASE:-release-name}"

_template() {
  helm template "$RELEASE" "$CHART" -f "$1" 2>&1
}

assert_renders() {
  local name=$1 values=$2
  if helm template "$RELEASE" "$CHART" -f "$values" >/dev/null 2>&1; then
    echo "PASS [render] $name"; PASS=$((PASS+1))
  else
    echo "FAIL [render] $name"; FAIL=$((FAIL+1))
    helm template "$RELEASE" "$CHART" -f "$values" 2>&1 | tail -20 | sed 's/^/    /'
  fi
}

assert_fails_with() {
  local name=$1 values=$2 needle=$3
  local out
  if out=$(_template "$values"); then
    echo "FAIL [guard] $name -- expected failure but render succeeded"
    FAIL=$((FAIL+1))
  elif [[ "$out" == *"$needle"* ]]; then
    echo "PASS [guard] $name"; PASS=$((PASS+1))
  else
    echo "FAIL [guard] $name -- error did not contain '$needle':"
    echo "$out" | tail -10 | sed 's/^/    /'
    FAIL=$((FAIL+1))
  fi
}

assert_yq() {
  local name=$1 values=$2 expr=$3 expected=$4
  local actual
  if ! actual=$(helm template "$RELEASE" "$CHART" -f "$values" 2>/dev/null | yq -r "$expr" 2>/dev/null); then
    echo "FAIL [yq] $name -- render or yq failed"; FAIL=$((FAIL+1)); return
  fi
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS [yq] $name"; PASS=$((PASS+1))
  else
    echo "FAIL [yq] $name -- expected '$expected', got '$actual'"
    FAIL=$((FAIL+1))
  fi
}

assert_yq_exists() {
  local name=$1 values=$2 expr=$3
  local count
  count=$(helm template "$RELEASE" "$CHART" -f "$values" 2>/dev/null | yq -r "[$expr] | length" 2>/dev/null || echo 0)
  if [[ "${count:-0}" -ge 1 ]]; then
    echo "PASS [exists] $name"; PASS=$((PASS+1))
  else
    echo "FAIL [exists] $name -- no docs matched"; FAIL=$((FAIL+1))
  fi
}

assert_yq_absent() {
  local name=$1 values=$2 expr=$3
  local count
  count=$(helm template "$RELEASE" "$CHART" -f "$values" 2>/dev/null | yq -r "[$expr] | length" 2>/dev/null || echo 0)
  if [[ "${count:-0}" -eq 0 ]]; then
    echo "PASS [absent] $name"; PASS=$((PASS+1))
  else
    echo "FAIL [absent] $name -- expected 0 matches, got $count"; FAIL=$((FAIL+1))
  fi
}
```

- [ ] **Step 3: Mark executable, verify it runs**

Run:

```bash
chmod +x moodle/tests/run.sh
moodle/tests/run.sh
```

Expected output:

```
PASSED 0  (no failures)
```

- [ ] **Step 4: Commit**

```bash
cd /Users/compass/projects/charts
git add moodle/tests/run.sh moodle/tests/lib.sh
git commit -m "test(moodle): scaffold helm-template assertion runner"
```

---

## Task 2: Add `db.type` and `db.mariadb.enabled` to values.yaml; bump Chart.yaml

**Goal:** Introduce the new value defaults without changing any template behavior. Chart still renders identically for default values.

**Files:**
- Modify: `moodle/Chart.yaml` (version bump only at this task; the dependency `condition` flip is Task 5)
- Modify: `moodle/values.yaml`
- Create: `moodle/tests/values/internal-mariadb.yaml`
- Modify: `moodle/tests/run.sh`

- [ ] **Step 1: Write the failing test**

Create `moodle/tests/values/internal-mariadb.yaml`:

```yaml
# Default-shaped values for the internal-mariadb scenario.
# This is intentionally minimal — defaults from values.yaml supply the rest.
ingress:
  enabled: false
```

Append to `moodle/tests/run.sh` after the `# === Render tests ===` marker:

```bash
assert_renders "default internal mariadb" "$HERE/values/internal-mariadb.yaml"

assert_yq "default MOODLE_DB_TYPE=mariadb" \
  "$HERE/values/internal-mariadb.yaml" \
  '... | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_TYPE") | .value' \
  "mariadb"

assert_yq_absent "no postgresql CR for default" \
  "$HERE/values/internal-mariadb.yaml" \
  '. | select((.apiVersion // "") == "acid.zalan.do/v1" and (.kind // "") == "postgresql")'
```

- [ ] **Step 2: Run the tests to verify they pass on the current chart**

Run:

```bash
moodle/tests/run.sh
```

Expected: all three assertions PASS — these capture *current* behavior so the upcoming values changes don't regress it.

- [ ] **Step 3: Bump chart version**

Edit `moodle/Chart.yaml`:

```yaml
# old
version: 0.2.15
# new
version: 0.3.0
```

- [ ] **Step 4: Add new values to `values.yaml`**

Find the `db:` block (around line 93) and add `type:` and `mariadb:` keys at the top, leaving the existing `architecture`, `db.db`, and `auth` blocks below. Then add the `postgres:` subblock at the end of the `db:` section. The file is long; the diff is:

Before:

```yaml
db:
  enabled: true
  ## standalone or replication
  architecture: standalone
  # use default image from upstream
  db:
    type: mariadb
  auth:
    #rootPassword:
    database: &dbName moodle
    username: &dbUser moodle
```

After:

```yaml
db:
  enabled: true
  ## Engine selector. mariadb (default) | postgres.
  ## When postgres, the chart renders a postgresql.acid.zalan.do CR consumed
  ## by a pre-installed zalando postgres-operator (the operator itself is NOT
  ## installed by this chart).
  type: mariadb
  ## Gates the bundled mariadb subchart via Chart.yaml condition.
  ## Must be:
  ##   true  when db.enabled=true AND db.type=mariadb (the default common case)
  ##   false when db.type=postgres
  ##   false when db.enabled=false + externalDatabase.enabled=true
  ##         (external-mariadb users must set this explicitly when upgrading)
  ## The validation guard rejects mismatches at template time.
  mariadb:
    enabled: true
  ## standalone or replication
  architecture: standalone
  # DEPRECATED: use db.type instead. This field is retained for one minor
  # version for backward compatibility but is no longer consulted for engine
  # selection — db.type drives MOODLE_DB_TYPE via the moodle.dbDialect helper.
  db:
    type: mariadb
  auth:
    #rootPassword:
    database: &dbName moodle
    username: &dbUser moodle
  ## Postgres (zalando postgres-operator). Only consulted when db.type=postgres.
  postgres:
    ## Required by the operator. clusterName must start with teamId.
    teamId: ctlt
    ## Defaults to "<teamId>-<release>-moodle" when empty.
    clusterName: ""
    numberOfInstances: 2
    version: "16"
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 1
        memory: 1Gi
    tolerations: []
    nodeAffinity: {}
    volume:
      size: 10Gi
      storageClass: ""
    ## Database + role created by the operator. Moodle authenticates as `username`.
    database: moodle
    username: moodle
    ## Continuous WAL archiving via the operator. Off by default.
    ## AWS credentials must reach the postgres pods via cluster-level setup
    ## (IRSA, pod-identity, or operator env) — the chart does not wire them.
    backup:
      enabled: false
      s3Bucket: ""
      s3Region: ""
      s3Endpoint: ""
      retentionDays: 7
    ## Deep-merged into the rendered CR's spec: for fields not surfaced above.
    extraManifest: {}
```

- [ ] **Step 5: Run the tests to verify defaults still work**

Run:

```bash
moodle/tests/run.sh
```

Expected: same three PASSes. The new values are additive defaults; behavior is unchanged because nothing reads them yet.

- [ ] **Step 6: Commit**

```bash
git add moodle/Chart.yaml moodle/values.yaml moodle/tests/run.sh moodle/tests/values/internal-mariadb.yaml
git commit -m "feat(moodle): add db.type, db.mariadb.enabled, db.postgres.* values

No behavior change yet. Defaults preserve current internal-mariadb path.
Chart version bumped 0.2.15 -> 0.3.0 to mark the start of the new
db.type / postgres-operator surface."
```

---

## Task 3: Add `_validate.tpl` with all six guard rules

**Goal:** Wire fail-fast validation so misconfigurations are caught at `helm template` time with clear messages. The shib-postgres rule references `moodle.dbDialect`, which doesn't exist yet — define a temporary inline check that reads `db.type` directly, then refactor in Task 4.

**Files:**
- Create: `moodle/templates/_validate.tpl`
- Modify: `moodle/templates/deployment.yaml` (add include at top)
- Create: `moodle/tests/values/invalid-postgres-mariadb-on.yaml`
- Create: `moodle/tests/values/invalid-mariadb-mariadb-off.yaml`
- Create: `moodle/tests/values/invalid-both-enabled.yaml`
- Create: `moodle/tests/values/invalid-external-mariadb-still-on.yaml`
- Create: `moodle/tests/values/invalid-bad-type.yaml`
- Create: `moodle/tests/values/invalid-shib-postgres.yaml`
- Modify: `moodle/tests/run.sh`

- [ ] **Step 1: Write the failing tests**

Create `moodle/tests/values/invalid-postgres-mariadb-on.yaml`:

```yaml
db:
  enabled: true
  type: postgres
  mariadb:
    enabled: true   # WRONG: must be false when db.type=postgres
```

Create `moodle/tests/values/invalid-mariadb-mariadb-off.yaml`:

```yaml
db:
  enabled: true
  type: mariadb
  mariadb:
    enabled: false  # WRONG: must be true when db.type=mariadb
```

Create `moodle/tests/values/invalid-both-enabled.yaml`:

```yaml
db:
  enabled: true
externalDatabase:
  enabled: true     # WRONG: mutually exclusive with db.enabled
```

Create `moodle/tests/values/invalid-external-mariadb-still-on.yaml`:

```yaml
db:
  enabled: false
  mariadb:
    enabled: true   # WRONG: must be false when externalDatabase is on
externalDatabase:
  enabled: true
  user: moodle
  password: x
```

Create `moodle/tests/values/invalid-bad-type.yaml`:

```yaml
db:
  enabled: true
  type: banana
  mariadb:
    enabled: true
```

Create `moodle/tests/values/invalid-shib-postgres.yaml`:

```yaml
db:
  enabled: true
  type: postgres
  mariadb:
    enabled: false
shib:
  enabled: true
```

Append to `moodle/tests/run.sh` under `# === Guard tests ===`:

```bash
assert_fails_with "guard: postgres + mariadb subchart on" \
  "$HERE/values/invalid-postgres-mariadb-on.yaml" \
  "db.type=postgres requires db.mariadb.enabled=false"

assert_fails_with "guard: mariadb + mariadb subchart off" \
  "$HERE/values/invalid-mariadb-mariadb-off.yaml" \
  "db.type=mariadb requires db.mariadb.enabled=true"

assert_fails_with "guard: db.enabled + externalDatabase.enabled" \
  "$HERE/values/invalid-both-enabled.yaml" \
  "db.enabled and externalDatabase.enabled are mutually exclusive"

assert_fails_with "guard: external mariadb but subchart still on" \
  "$HERE/values/invalid-external-mariadb-still-on.yaml" \
  "externalDatabase.enabled=true requires db.mariadb.enabled=false"

assert_fails_with "guard: bad db.type" \
  "$HERE/values/invalid-bad-type.yaml" \
  'db.type must be "mariadb" or "postgres"'

assert_fails_with "guard: shib + postgres" \
  "$HERE/values/invalid-shib-postgres.yaml" \
  "shib.enabled=true is not supported with postgres"
```

- [ ] **Step 2: Run tests, expect failures**

Run:

```bash
moodle/tests/run.sh
```

Expected: all six new guard tests FAIL with `expected failure but render succeeded` because no guard exists yet.

- [ ] **Step 3: Implement the validation guard**

Create `moodle/templates/_validate.tpl`:

```gotpl
{{/*
Validation guards. Renders nothing; called via:
  {{- include "moodle.validateDb" . -}}
from any always-rendered file. Fails `helm template` early with an
actionable message instead of letting a misconfig boot a broken pod.
*/}}
{{- define "moodle.validateDb" -}}
{{- if not (or (eq .Values.db.type "mariadb") (eq .Values.db.type "postgres")) -}}
{{- fail (printf "db.type must be \"mariadb\" or \"postgres\", got %q" .Values.db.type) -}}
{{- end -}}
{{- if and .Values.db.enabled (eq .Values.db.type "postgres") .Values.db.mariadb.enabled -}}
{{- fail "db.type=postgres requires db.mariadb.enabled=false (the bundled mariadb subchart must be disabled)" -}}
{{- end -}}
{{- if and .Values.db.enabled (eq .Values.db.type "mariadb") (not .Values.db.mariadb.enabled) -}}
{{- fail "db.type=mariadb requires db.mariadb.enabled=true" -}}
{{- end -}}
{{- if and .Values.db.enabled .Values.externalDatabase.enabled -}}
{{- fail "db.enabled and externalDatabase.enabled are mutually exclusive" -}}
{{- end -}}
{{- if and (not .Values.db.enabled) .Values.externalDatabase.enabled .Values.db.mariadb.enabled -}}
{{- fail "externalDatabase.enabled=true requires db.mariadb.enabled=false (the bundled mariadb subchart must be disabled)" -}}
{{- end -}}
{{- if and .Values.shib.enabled (eq .Values.db.type "postgres") -}}
{{- fail "shib.enabled=true is not supported with postgres in this chart version" -}}
{{- end -}}
{{- end -}}
```

(The shib check reads `db.type` directly here; Task 4 swaps it to `moodle.dbDialect` once that helper exists.)

- [ ] **Step 4: Wire the guard into a guaranteed-rendered file**

Edit `moodle/templates/deployment.yaml`. Insert at the very top, before `apiVersion:`:

```yaml
{{- include "moodle.validateDb" . -}}
apiVersion: apps/v1
kind: Deployment
...
```

- [ ] **Step 5: Run tests, expect all passes**

Run:

```bash
moodle/tests/run.sh
```

Expected: all six guard tests PASS, plus the existing render/yq tests still PASS.

- [ ] **Step 6: Commit**

```bash
git add moodle/templates/_validate.tpl moodle/templates/deployment.yaml moodle/tests/values/invalid-*.yaml moodle/tests/run.sh
git commit -m "feat(moodle): fail-fast validation guard for db.type misconfigs

Catches all six known invalid combinations at helm template time:
- postgres + mariadb subchart on
- mariadb + mariadb subchart off
- db.enabled and externalDatabase.enabled both true
- external mariadb but subchart still on
- invalid db.type value
- shib + postgres (deferred feature)"
```

---

## Task 4: Add `moodle.dbDialect`, wire `MOODLE_DB_TYPE` through it

**Goal:** Introduce the dialect helper. Default behavior unchanged for `db.type: mariadb` (returns `mariadb`). Refactor the validate.tpl shib check to use it.

**Files:**
- Modify: `moodle/templates/_helpers.tpl`
- Modify: `moodle/templates/_validate.tpl`
- Create: `moodle/tests/values/internal-postgres-shallow.yaml` (preview-only; real internal-postgres values come in Task 6)
- Modify: `moodle/tests/run.sh`

- [ ] **Step 1: Create the postgres test fixture**

Create `moodle/tests/values/internal-postgres-shallow.yaml`:

```yaml
# Minimal postgres-shaped values that exercise db.type=postgres BUT do not
# render the postgresql CR (template doesn't exist yet — added in Task 6).
# Purpose at this stage: prove MOODLE_DB_TYPE flips to "pgsql".
db:
  enabled: true
  type: postgres
  mariadb:
    enabled: false
ingress:
  enabled: false
```

- [ ] **Step 2: Add the `--show-only` helper to `lib.sh` and append the failing assertion**

Targeting only `templates/deployment.yaml` keeps the assertion isolated from later-task rendering changes. Append to `moodle/tests/lib.sh`:

```bash
assert_yq_partial() {
  local name=$1 values=$2 show=$3 expr=$4 expected=$5
  local actual
  if ! actual=$(helm template "$RELEASE" "$CHART" -f "$values" --show-only "$show" 2>/dev/null | yq -r "$expr" 2>/dev/null); then
    echo "FAIL [yq] $name -- render or yq failed"; FAIL=$((FAIL+1)); return
  fi
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS [yq] $name"; PASS=$((PASS+1))
  else
    echo "FAIL [yq] $name -- expected '$expected', got '$actual'"
    FAIL=$((FAIL+1))
  fi
}
```

Append to `moodle/tests/run.sh`:

```bash
assert_yq_partial "postgres MOODLE_DB_TYPE=pgsql" \
  "$HERE/values/internal-postgres-shallow.yaml" \
  templates/deployment.yaml \
  '. | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_TYPE") | .value' \
  "pgsql"
```

- [ ] **Step 3: Run tests, expect failure**

Run:

```bash
moodle/tests/run.sh
```

Expected: the new `assert_yq_partial` FAILs because `MOODLE_DB_TYPE` still comes from `default "mariadb" .Values.db.db.type`, which has no awareness of the new `db.type` field. The render itself succeeds because `--show-only templates/deployment.yaml` does not exercise the (yet-to-be-added) postgres CR template, and `helm template` does not validate that referenced Secrets exist at runtime.

- [ ] **Step 4: Add `moodle.dbDialect` helper**

Before writing the helper, run this command to confirm the upstream Moodle image's expected pgsql string:

```bash
git -C /tmp/moodle-docker-check rev-parse --is-inside-work-tree 2>/dev/null \
  || git clone --depth 1 https://github.com/ubc/moodle-docker.git /tmp/moodle-docker-check
grep -RE "MOODLE_DB_TYPE|MOODLE_DATABASE_TYPE|pgsql|mariadb|mysqli" /tmp/moodle-docker-check | head -20
```

Confirm `pgsql` is the value the image's entrypoint maps to PostgreSQL. If a different string is in use (e.g. `pgsql` vs `postgres`), update the helper accordingly before continuing. The spec's "Open Questions" section explicitly defers this confirmation to implementation.

Append to `moodle/templates/_helpers.tpl`:

```gotpl
{{/*
Return the Moodle DB dialect string for MOODLE_DB_TYPE. Reads db.type as
the source of truth; falls back to the legacy db.db.type for mariadb-only
backward compatibility (deprecated, removed in a future minor version).
*/}}
{{- define "moodle.dbDialect" -}}
{{- if eq .Values.db.type "postgres" -}}pgsql
{{- else -}}{{- default "mariadb" .Values.db.db.type -}}
{{- end -}}
{{- end -}}
```

- [ ] **Step 5: Wire `MOODLE_DB_TYPE` through `moodle.dbDialect`**

Find this line in `moodle/templates/_helpers.tpl` (currently around line 127–128 inside the `moodle.app.spec` define):

```gotpl
- name: MOODLE_DB_TYPE
  value: {{ default "mariadb" .Values.db.db.type | quote }}
```

Replace with:

```gotpl
- name: MOODLE_DB_TYPE
  value: {{ include "moodle.dbDialect" . | quote }}
```

- [ ] **Step 6: Refactor `_validate.tpl` shib check to use the helper**

In `moodle/templates/_validate.tpl`, change the shib guard from:

```gotpl
{{- if and .Values.shib.enabled (eq .Values.db.type "postgres") -}}
```

to:

```gotpl
{{- if and .Values.shib.enabled (eq (include "moodle.dbDialect" .) "pgsql") -}}
```

Functionally identical for the cases the spec models, but matches the dialect contract going forward (e.g., a future external-postgres path also blocks shib).

- [ ] **Step 7: Run tests, expect all passes**

Run:

```bash
moodle/tests/run.sh
```

Expected: the new `pgsql` assertion PASSes. Default `MOODLE_DB_TYPE=mariadb` still PASSes. Guard tests still PASS.

- [ ] **Step 8: Commit**

```bash
git add moodle/templates/_helpers.tpl moodle/templates/_validate.tpl moodle/tests/values/internal-postgres-shallow.yaml moodle/tests/run.sh moodle/tests/lib.sh
git commit -m "feat(moodle): add moodle.dbDialect helper, drive MOODLE_DB_TYPE from db.type

db.type=mariadb (default) keeps emitting MOODLE_DB_TYPE=mariadb.
db.type=postgres emits pgsql. The legacy db.db.type field remains
honored for one minor version as a fallback for the mariadb path."
```

---

## Task 5: Flip Chart.yaml subchart condition; branch database helpers on `db.type`

**Goal:** Switch the bundled mariadb subchart's render gate from `db.enabled` to `db.mariadb.enabled`, then teach every `moodle.database*` helper to return the right value for postgres internal.

**Files:**
- Modify: `moodle/Chart.yaml`
- Modify: `moodle/templates/_helpers.tpl`
- Create: `moodle/tests/values/external-mariadb.yaml`
- Modify: `moodle/tests/run.sh`

- [ ] **Step 1: Write the failing tests**

Create `moodle/tests/values/external-mariadb.yaml`:

```yaml
db:
  enabled: false
  type: mariadb
  mariadb:
    enabled: false
externalDatabase:
  enabled: true
  user: moodle
  password: testpw
  service:
    externalName: db.example.com
ingress:
  enabled: false
```

Append to `moodle/tests/run.sh`:

```bash
assert_renders "external mariadb scenario" "$HERE/values/external-mariadb.yaml"

assert_yq_absent "external mariadb: no mariadb StatefulSet" \
  "$HERE/values/external-mariadb.yaml" \
  '. | select((.kind // "") == "StatefulSet" and ((.metadata.name // "") | test("mariadb")))'

assert_yq "external mariadb: ExternalName service on port 3306" \
  "$HERE/values/external-mariadb.yaml" \
  '... | select(.kind == "Service" and .spec.type == "ExternalName") | .spec.ports[0].port' \
  "3306"

# Internal-postgres helper outputs (CR not rendered yet — that's Task 6;
# the helpers must already produce the right values though, since the
# Deployment env block reads them).
assert_yq_partial "postgres internal: MOODLE_DB_HOST is clusterName" \
  "$HERE/values/internal-postgres-shallow.yaml" \
  templates/deployment.yaml \
  '. | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_HOST") | .value' \
  "ctlt-release-name-moodle"

assert_yq_partial "postgres internal: MOODLE_DB_PORT=5432" \
  "$HERE/values/internal-postgres-shallow.yaml" \
  templates/deployment.yaml \
  '. | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_PORT") | .value' \
  "5432"

assert_yq_partial "postgres internal: MOODLE_DB_PASSWORD references operator secret" \
  "$HERE/values/internal-postgres-shallow.yaml" \
  templates/deployment.yaml \
  '. | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_PASSWORD") | .valueFrom.secretKeyRef.name' \
  "moodle.ctlt-release-name-moodle.credentials.postgresql.acid.zalan.do"

assert_yq_partial "postgres internal: MOODLE_DB_PASSWORD secret key is 'password'" \
  "$HERE/values/internal-postgres-shallow.yaml" \
  templates/deployment.yaml \
  '. | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_PASSWORD") | .valueFrom.secretKeyRef.key' \
  "password"
```

(Helm's default release name in `helm template` is `release-name`, hence `ctlt-release-name-moodle` for the computed clusterName when `db.postgres.clusterName` is empty.)

- [ ] **Step 2: Run tests, expect failures**

Run:

```bash
moodle/tests/run.sh
```

Expected: the four `postgres internal` helper assertions FAIL because the helpers still return mariadb values. The external-mariadb tests may also FAIL on subchart-rendering until Step 3.

- [ ] **Step 3: Flip the subchart condition in `Chart.yaml`**

Change:

```yaml
dependencies:
  - name: mariadb
    condition: db.enabled
    version: "*"
    alias: db
    repository: https://ubc.github.io/charts
    tags:
      - moodle-database
```

to:

```yaml
dependencies:
  - name: mariadb
    condition: db.mariadb.enabled
    version: "*"
    alias: db
    repository: https://ubc.github.io/charts
    tags:
      - moodle-database
```

Then run `helm dependency update` so the lock matches the new condition (the tarball is the same, only the lock metadata changes):

```bash
cd moodle && helm dependency update . && cd ..
```

- [ ] **Step 4: Branch helpers on `db.type` for postgres internal**

In `moodle/templates/_helpers.tpl`, add a clusterName helper near the top of the file (after `moodle.fullname`):

```gotpl
{{/*
Compute the postgresql clusterName: explicit user value, else "<teamId>-<release>-<chartname>".
The operator requires the name to start with the teamId.
*/}}
{{- define "moodle.postgresClusterName" -}}
{{- if .Values.db.postgres.clusterName -}}
  {{- .Values.db.postgres.clusterName -}}
{{- else -}}
  {{- printf "%s-%s-moodle" .Values.db.postgres.teamId .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
```

Then update each existing `moodle.database*` helper. Find this block:

```gotpl
{{- define "moodle.databaseHost" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.architecture "replication" }}
        {{- printf "%s-primary" (include "moodle.db.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- printf "%s" (include "moodle.db.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.enabled -}}
    {{- include "moodle.externalDatabaseName" . -}}
{{- end -}}
{{- end -}}
```

Replace with:

```gotpl
{{- define "moodle.databaseHost" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.type "postgres" -}}
        {{- include "moodle.postgresClusterName" . -}}
    {{- else if eq .Values.db.architecture "replication" }}
        {{- printf "%s-primary" (include "moodle.db.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- printf "%s" (include "moodle.db.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.enabled -}}
    {{- include "moodle.externalDatabaseName" . -}}
{{- end -}}
{{- end -}}
```

Replace `moodle.databasePort`:

```gotpl
{{- define "moodle.databasePort" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.type "postgres" -}}5432{{- else -}}3306{{- end -}}
{{- else if .Values.externalDatabase.enabled -}}
    {{- if .Values.externalDatabase.port -}}
        {{- printf "%d" (.Values.externalDatabase.port | int) -}}
    {{- else if eq .Values.db.type "postgres" -}}5432
    {{- else -}}3306
    {{- end -}}
{{- end -}}
{{- end -}}
```

Replace `moodle.databaseName`:

```gotpl
{{- define "moodle.databaseName" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.type "postgres" -}}
        {{- .Values.db.postgres.database -}}
    {{- else -}}
        {{- .Values.db.auth.database -}}
    {{- end -}}
{{- else if .Values.externalDatabase.enabled -}}
    {{- .Values.externalDatabase.database -}}
{{- end -}}
{{- end -}}
```

Replace `moodle.databaseUser`:

```gotpl
{{- define "moodle.databaseUser" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.type "postgres" -}}
        {{- .Values.db.postgres.username -}}
    {{- else -}}
        {{- .Values.db.auth.username -}}
    {{- end -}}
{{- else if .Values.externalDatabase.enabled -}}
    {{- .Values.externalDatabase.user -}}
{{- end -}}
{{- end -}}
```

Replace `moodle.databaseSecretName`:

```gotpl
{{- define "moodle.databaseSecretName" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.type "postgres" -}}
        {{- printf "%s.%s.credentials.postgresql.acid.zalan.do"
              .Values.db.postgres.username
              (include "moodle.postgresClusterName" .) -}}
    {{- else if and .Values.db.auth.existingSecret .Values.db.auth.userPasswordKey -}}
        {{- printf "%s" .Values.db.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s-user-password" (include "moodle.db.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.enabled -}}
    {{- if .Values.externalDatabase.existingSecret -}}
        {{- tpl .Values.externalDatabase.existingSecret $ -}}
    {{- else -}}
        {{- printf "%s" (include "moodle.fullname" .) -}}
    {{- end -}}
{{- end -}}
{{- end -}}
```

Replace `moodle.databaseSecretKey`:

```gotpl
{{- define "moodle.databaseSecretKey" -}}
{{- if .Values.db.enabled }}
    {{- if eq .Values.db.type "postgres" -}}password
    {{- else if and .Values.db.auth.existingSecret .Values.db.auth.userPasswordKey -}}
        {{- printf "%s" .Values.db.auth.userPasswordKey -}}
    {{- else -}}
        {{- printf "password-%s" (include "moodle.databaseUser" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.enabled -}}
    db_password
{{- end -}}
{{- end -}}
```

The `moodle.databaseRootSecretName` and `moodle.databaseRootSecretKey` helpers stay unchanged. Callers (e.g., the mariadb subchart's bootstrap) only use them when the mariadb subchart is rendering, which is gated off when `db.type=postgres`.

- [ ] **Step 5: Run tests, expect all passes**

Run:

```bash
moodle/tests/run.sh
```

Expected: every assertion passes — the four postgres-helper checks, the three external-mariadb checks, and all previous assertions.

- [ ] **Step 6: Commit**

```bash
git add moodle/Chart.yaml moodle/Chart.lock moodle/templates/_helpers.tpl moodle/tests/values/external-mariadb.yaml moodle/tests/run.sh
git commit -m "feat(moodle): branch database helpers on db.type for postgres

- Chart.yaml dependency condition flips db.enabled -> db.mariadb.enabled
- moodle.postgresClusterName helper defaults to <teamId>-<release>-moodle
- moodle.databaseHost/Port/Name/User/SecretName/SecretKey return the
  zalando-operator-shaped values when db.type=postgres
- External-mariadb path verified with a new test scenario

Helpers are the single seam every workload (Deployment, CronJob, shibd)
reads through, so wiring postgres values here lets later tasks add the
CR template without touching the workload manifests."
```

---

## Task 6: Render the postgresql CR

**Goal:** Add the operator CR template so `db.type: postgres` produces the database resource. Update existing `internal-postgres-shallow.yaml` test scenario into a full `internal-postgres.yaml`.

**Files:**
- Create: `moodle/templates/postgresql.yaml`
- Rename: `moodle/tests/values/internal-postgres-shallow.yaml` → `moodle/tests/values/internal-postgres.yaml`
- Modify: `moodle/tests/run.sh`

- [ ] **Step 1: Promote the postgres test fixture**

```bash
git mv moodle/tests/values/internal-postgres-shallow.yaml moodle/tests/values/internal-postgres.yaml
```

Update its contents to a fully-shaped scenario:

```yaml
# Internal postgres via zalando postgres-operator.
db:
  enabled: true
  type: postgres
  mariadb:
    enabled: false
  postgres:
    teamId: ctlt
    numberOfInstances: 2
    version: "16"
    volume:
      size: 5Gi
    database: moodle
    username: moodle
    extraManifest:
      maintenanceWindows:
        - "Sun:00:00-Sun:03:00"
ingress:
  enabled: false
```

Update every reference to `internal-postgres-shallow.yaml` in `moodle/tests/run.sh` to `internal-postgres.yaml`.

- [ ] **Step 2: Write the failing tests**

Append to `moodle/tests/run.sh`:

```bash
assert_renders "internal postgres scenario" "$HERE/values/internal-postgres.yaml"

assert_yq "internal postgres: exactly one postgresql CR" \
  "$HERE/values/internal-postgres.yaml" \
  '[. | select((.apiVersion // "") == "acid.zalan.do/v1" and (.kind // "") == "postgresql")] | length' \
  "1"

assert_yq "internal postgres: CR name is teamId-release-moodle" \
  "$HERE/values/internal-postgres.yaml" \
  '. | select((.kind // "") == "postgresql") | .metadata.name' \
  "ctlt-release-name-moodle"

assert_yq "internal postgres: numberOfInstances=2" \
  "$HERE/values/internal-postgres.yaml" \
  '. | select((.kind // "") == "postgresql") | .spec.numberOfInstances' \
  "2"

assert_yq "internal postgres: pg version=16" \
  "$HERE/values/internal-postgres.yaml" \
  '. | select((.kind // "") == "postgresql") | .spec.postgresql.version' \
  "16"

assert_yq "internal postgres: databases.moodle owner is moodle" \
  "$HERE/values/internal-postgres.yaml" \
  '. | select((.kind // "") == "postgresql") | .spec.databases.moodle' \
  "moodle"

assert_yq "internal postgres: extraManifest deep-merged" \
  "$HERE/values/internal-postgres.yaml" \
  '. | select((.kind // "") == "postgresql") | .spec.maintenanceWindows[0]' \
  "Sun:00:00-Sun:03:00"

assert_yq_absent "internal postgres: no mariadb StatefulSet" \
  "$HERE/values/internal-postgres.yaml" \
  '. | select((.kind // "") == "StatefulSet" and ((.metadata.name // "") | test("mariadb")))'
```

- [ ] **Step 3: Run tests, expect failures**

Run:

```bash
moodle/tests/run.sh
```

Expected: all eight new assertions FAIL because no postgresql CR is rendered yet.

- [ ] **Step 4: Implement the CR template**

Before writing it, confirm one operator behavior the spec deferred to implementation: what does the operator do with `users: { <name>: [] }` (empty flag list)? Read the operator's user-roles documentation (`https://github.com/zalando/postgres-operator/blob/master/docs/reference/cluster_manifest.md`) and verify that an empty list creates a plain LOGIN role (no `superuser` / `createdb` flags). If empty lists are rejected or interpreted unexpectedly, change the template to `[]` → `["createdb"]` (or whatever the docs require for a role that owns its database). The spec accepts either; document the chosen value in `values.yaml` so users can override.

Create `moodle/templates/postgresql.yaml`:

```yaml
{{- if and .Values.db.enabled (eq .Values.db.type "postgres") -}}
{{- include "moodle.validateDb" . -}}
apiVersion: acid.zalan.do/v1
kind: postgresql
metadata:
  name: {{ include "moodle.postgresClusterName" . }}
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
    {{ .Values.db.postgres.username }}: []
  resources:
    {{- toYaml .Values.db.postgres.resources | nindent 4 }}
  {{- with .Values.db.postgres.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.db.postgres.nodeAffinity }}
  nodeAffinity:
    {{- toYaml . | nindent 4 }}
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
    - name: BACKUP_NUM_TO_RETAIN
      value: {{ .Values.db.postgres.backup.retentionDays | quote }}
  {{- end }}
  {{- with .Values.db.postgres.extraManifest }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end -}}
```

- [ ] **Step 5: Run tests, expect all passes**

Run:

```bash
moodle/tests/run.sh
```

Expected: all assertions PASS, including the eight new postgres-CR ones.

- [ ] **Step 6: Commit**

```bash
git add moodle/templates/postgresql.yaml moodle/tests/values/internal-postgres.yaml moodle/tests/run.sh
# The git mv from Step 1 already staged the rename of the shallow fixture.
git commit -m "feat(moodle): render postgresql.acid.zalan.do CR for db.type=postgres

CR fields: teamId, numberOfInstances, postgresql.version, volume,
databases, users, resources, tolerations, nodeAffinity, optional
WAL-G backup env, and a deep-merged extraManifest escape hatch.
Cluster name defaults to '<teamId>-<release>-moodle' (operator
requires names to start with teamId)."
```

---

## Task 7: External-postgres path

**Goal:** Make `externalDatabase.enabled: true + db.type: postgres` produce a working ExternalName service on port 5432 with the right `MOODLE_DB_*` wiring.

**Files:**
- Modify: `moodle/templates/service.yaml`
- Create: `moodle/tests/values/external-postgres.yaml`
- Modify: `moodle/tests/run.sh`

- [ ] **Step 1: Locate the affected lines**

`moodle/templates/service.yaml` lines 68–85 render the ExternalName Service when `externalDatabase.enabled`. Lines 81–82 read `.Values.externalDatabase.service.port` directly:

```yaml
  ports:
  - port: {{ .Values.externalDatabase.service.port }}
    targetPort: {{ .Values.externalDatabase.service.port }}
```

`moodle/values.yaml` currently sets `externalDatabase.port: 3306` (line ~107) AND `externalDatabase.service.port: 3306` (line ~116). Both are hardcoded mariadb defaults. The fix is to drop both literal defaults so the helper (`moodle.databasePort`, already engine-aware after Task 5) computes the value, and to switch the Service template to call the helper.

- [ ] **Step 2: Write the failing tests**

Create `moodle/tests/values/external-postgres.yaml`:

```yaml
db:
  enabled: false
  type: postgres
  mariadb:
    enabled: false
externalDatabase:
  enabled: true
  user: moodle
  password: testpw
  service:
    externalName: pg.example.com
ingress:
  enabled: false
```

Append to `moodle/tests/run.sh`:

```bash
assert_renders "external postgres scenario" "$HERE/values/external-postgres.yaml"

assert_yq "external postgres: ExternalName service on port 5432" \
  "$HERE/values/external-postgres.yaml" \
  '... | select(.kind == "Service" and .spec.type == "ExternalName") | .spec.ports[0].port' \
  "5432"

assert_yq "external postgres: MOODLE_DB_TYPE=pgsql" \
  "$HERE/values/external-postgres.yaml" \
  '... | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_TYPE") | .value' \
  "pgsql"

assert_yq_absent "external postgres: no postgresql CR" \
  "$HERE/values/external-postgres.yaml" \
  '. | select((.kind // "") == "postgresql")'
```

- [ ] **Step 3: Run tests, expect failures**

Run:

```bash
moodle/tests/run.sh
```

Expected: the ExternalName port assertion FAILs (defaults to `3306` from `values.yaml`).

- [ ] **Step 4: Make the ExternalName port engine-aware**

Edit `moodle/values.yaml`. Change:

```yaml
externalDatabase:
  enabled: false
  port: 3306
  database: moodle
  user: moodle
  password:
  existingSecret:

  service:
    enabled: true
    externalName: ""
    port: 3306
```

to:

```yaml
externalDatabase:
  enabled: false
  ## Engine-derived default: 3306 (db.type=mariadb) or 5432 (db.type=postgres).
  ## Set explicitly to override.
  port:
  database: moodle
  user: moodle
  password:
  existingSecret:

  service:
    enabled: true
    externalName: ""
    ## Reserved for future use; the rendered Service port follows externalDatabase.port
    ## (or the engine default) via the moodle.databasePort helper.
    port:
```

Edit `moodle/templates/service.yaml` lines 81–82. Change:

```yaml
  ports:
  - port: {{ .Values.externalDatabase.service.port }}
    targetPort: {{ .Values.externalDatabase.service.port }}
```

to:

```yaml
  ports:
  - port: {{ include "moodle.databasePort" . }}
    targetPort: {{ include "moodle.databasePort" . }}
```

The `moodle.databasePort` helper (rewritten in Task 5) already returns `5432` when `db.type=postgres` and `externalDatabase.enabled=true`, `3306` for mariadb, and respects `externalDatabase.port` when explicitly set.

- [ ] **Step 5: Run tests, expect all passes**

Run:

```bash
moodle/tests/run.sh
```

Expected: all four new assertions PASS, plus the existing external-mariadb test still PASSes (port stays at 3306 because `db.type=mariadb`).

- [ ] **Step 6: Commit**

```bash
git add moodle/values.yaml moodle/templates/service.yaml moodle/tests/values/external-postgres.yaml moodle/tests/run.sh
git commit -m "feat(moodle): external-DB ExternalName port follows db.type

externalDatabase.port and externalDatabase.service.port both default at
template time via moodle.databasePort: 3306 for mariadb, 5432 for postgres.
Explicit values still win. New external-postgres test fixture covers this."
```

---

## Task 8: NOTES.txt + README updates

**Goal:** Print engine-aware connection details on `helm install`, and document the new surface and the upgrade note for external-mariadb users.

**Files:**
- Modify: `moodle/templates/NOTES.txt`
- Modify: `moodle/README.md`

- [ ] **Step 1: Append a database-info section to `NOTES.txt`**

The current `moodle/templates/NOTES.txt` (44 lines) prints two sections: (1) the Moodle URL, and (2) the admin login credentials. It does **not** print database details today. Don't refactor existing content — add a new section #3 at the bottom that branches on `db.type`.

Append to `moodle/templates/NOTES.txt`:

```gotpl

3. Database backend
{{- if eq .Values.db.type "postgres" }}

  This install uses **PostgreSQL** via the zalando postgres-operator.

  Cluster CR:     {{ include "moodle.postgresClusterName" . }} (kind: postgresql.acid.zalan.do/v1)
  Master service: {{ include "moodle.postgresClusterName" . }}.{{ .Release.Namespace }}.svc.cluster.local:5432
  Role:           {{ .Values.db.postgres.username }}
  Credentials:    Secret {{ printf "%s.%s.credentials.postgresql.acid.zalan.do" .Values.db.postgres.username (include "moodle.postgresClusterName" .) }}

  Note: The postgres-operator must already be installed and reconciling
        postgresql.acid.zalan.do resources. This chart does not install it.
  {{- if not .Values.db.postgres.backup.enabled }}

  WARNING: db.postgres.backup.enabled is false. No WAL archiving is configured.
           Set db.postgres.backup.enabled=true plus backup.s3Bucket and
           backup.s3Region to enable continuous backups.
  {{- end }}
{{- else if .Values.externalDatabase.enabled }}

  This install uses an **external** {{ include "moodle.dbDialect" . }} database at
  {{ .Values.externalDatabase.service.externalName }}:{{ include "moodle.databasePort" . }}.
{{- else }}

  This install uses the bundled **MariaDB** subchart at
  {{ include "moodle.databaseHost" . }}:{{ include "moodle.databasePort" . }}.
{{- end }}
```

- [ ] **Step 2: Update `README.md`**

Find the "Configuration" section. Add a new subsection "Database engine selection" that documents:

- `db.type: mariadb` (default) vs `db.type: postgres`
- The `db.mariadb.enabled` boolean and when users must set it explicitly
- The full `db.postgres.*` value tree (mirror what's in `values.yaml`)
- The upgrade note: "If you are upgrading from chart `0.2.x` and use `db.enabled: false` (external mariadb), you must add `db.mariadb.enabled: false` to your values file when upgrading to `0.3.x`. The chart will fail `helm template` with an actionable message if you forget."
- The non-goal: "This chart does not install the zalando postgres-operator. The operator must already be reconciling resources in the cluster."

Reference the spec at the top of the new subsection:
`> See docs/superpowers/specs/2026-05-07-moodle-postgres-support-design.md for the full design.`

- [ ] **Step 3: Render and spot-check**

Run:

```bash
helm template t moodle/ -f moodle/tests/values/internal-postgres.yaml --show-only templates/NOTES.txt
helm template t moodle/ -f moodle/tests/values/internal-mariadb.yaml --show-only templates/NOTES.txt
```

Expected: postgres render mentions the operator and the credentials secret name. Mariadb render is unchanged from before.

- [ ] **Step 4: Commit**

```bash
git add moodle/templates/NOTES.txt moodle/README.md
git commit -m "docs(moodle): NOTES.txt + README cover db.type=postgres path"
```

---

## Task 9: `values_postgres.yaml.example`

**Goal:** Hand ops a known-good starting values file for a postgres install.

**Files:**
- Create: `moodle/values_postgres.yaml.example`

- [ ] **Step 1: Write the file**

Create `moodle/values_postgres.yaml.example`:

```yaml
# Example overlay for installing Moodle on Postgres via the zalando
# postgres-operator. Save as values.yaml or pass with -f to helm install.
#
# Prerequisite: the postgres-operator is already installed and reconciling
# postgresql.acid.zalan.do resources in this cluster.

db:
  enabled: true
  type: postgres
  mariadb:
    enabled: false       # required when db.type=postgres
  postgres:
    teamId: ctlt
    numberOfInstances: 2
    version: "16"
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 1
        memory: 1Gi
    volume:
      size: 20Gi
      storageClass: ""
    database: moodle
    username: moodle
    backup:
      enabled: true
      s3Bucket: my-org-moodle-pg-wal
      s3Region: us-west-2
      retentionDays: 14

ingress:
  enabled: true
  hosts:
    - moodle.example.com

# All other values inherit from chart defaults. See values.yaml.
```

- [ ] **Step 2: Smoke-test the example**

Run:

```bash
helm template t moodle/ -f moodle/values_postgres.yaml.example >/dev/null
echo "exit=$?"
```

Expected: `exit=0`. (No assertions in the runner — this is a docs artifact. Smoke-test only.)

- [ ] **Step 3: Commit**

```bash
git add moodle/values_postgres.yaml.example
git commit -m "docs(moodle): values_postgres.yaml.example for the postgres path"
```

---

## Task 10: Backwards-compatibility check against existing devops values

**Goal:** Verify every consumer values file under `devops/configuration/moodle/` still renders cleanly after the chart changes. If any file uses `db.enabled: false` (external mariadb), the implementer must add `db.mariadb.enabled: false` in the same PR series in the devops repo.

**Files:**
- No chart files modified; this task is a verification checkpoint.

- [ ] **Step 1: Inventory consumer files**

Run:

```bash
ls /Users/compass/projects/devops/configuration/moodle/values_*.yaml 2>/dev/null
```

For each file:

```bash
for f in /Users/compass/projects/devops/configuration/moodle/values_*.yaml; do
  printf "\n=== %s ===\n" "$f"
  yq -r '.db.enabled // "(unset)"' "$f"
  yq -r '.externalDatabase.enabled // "(unset)"' "$f"
done
```

Record the matrix.

- [ ] **Step 2: Render each file against the chart**

```bash
for f in /Users/compass/projects/devops/configuration/moodle/values_*.yaml; do
  echo "Rendering $f"
  helm template t /Users/compass/projects/charts/moodle -f "$f" >/dev/null \
    && echo "  OK" || echo "  FAIL"
done
```

Expected: all render OK. Any FAILs are real BC breaks the implementer must address by editing the devops repo file. Most likely cause: `db.enabled: false` files now hit the validation guard.

- [ ] **Step 3: For any FAILs, add `db.mariadb.enabled: false` to the offending devops file**

This edit is in the **devops repo**, not the charts repo. Open a separate PR there. Verify with:

```bash
cd /Users/compass/projects/devops && git diff
helm template t /Users/compass/projects/charts/moodle -f configuration/moodle/<file>.yaml >/dev/null
```

(At plan-write time the charts-repo author verified all eight `values_*.yaml` files in the devops repo set `db.enabled: true`, so this step is expected to be a no-op. Re-verify because state may have drifted.)

- [ ] **Step 4: Commit if any chart-side notes were added**

If this task surfaced a CHANGELOG/release-notes file the chart should ship, add it now. Otherwise this task is verification-only and produces no commit on this branch.

---

## Task 11: Wire the test runner into CI

**Goal:** Run `moodle/tests/run.sh` on every push/PR alongside `ct lint`.

**Files:**
- Modify: `.github/workflows/lint-charts.yaml`

- [ ] **Step 1: Update the workflow**

Open `.github/workflows/lint-charts.yaml`. Add a new step at the end of the `lint` job:

```yaml
      - name: Install yq
        run: |
          curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
            -o /usr/local/bin/yq
          chmod +x /usr/local/bin/yq
          yq --version

      - name: Build moodle chart deps
        run: helm dependency build moodle

      - name: Run moodle render assertions
        run: bash moodle/tests/run.sh
```

`chart-testing-action` provisions Helm 3 and adds it to PATH. We run `helm dependency build` explicitly so the mariadb subchart tarball is present even when `ct lint` skipped moodle (it skips charts whose own files didn't change in the diff).

- [ ] **Step 2: Verify locally one last time**

Run:

```bash
moodle/tests/run.sh
```

Expected: full PASS line.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/lint-charts.yaml
git commit -m "ci: run moodle render assertions on every push

Adds yq install + a final step that exercises moodle/tests/run.sh.
Catches engine-selection regressions before they ship."
```

- [ ] **Step 4: Push to a branch and verify CI green**

```bash
git push -u origin <branch>
gh pr create --title "feat(moodle): postgres support via zalando postgres-operator" \
  --body "$(cat <<'EOF'
## Summary
- Adds `db.type: mariadb|postgres` engine selector to the moodle chart.
- Postgres path renders a `postgresql.acid.zalan.do` CR consumed by a
  pre-installed zalando postgres-operator. Operator install is out of scope.
- Branches `moodle.database*` helpers on `db.type`; new `moodle.dbDialect`
  helper drives `MOODLE_DB_TYPE`.
- Subchart condition `db.enabled` -> `db.mariadb.enabled` so the bundled
  mariadb subchart can be skipped while the chart still provisions a DB.
- Six fail-fast validation guards reject inconsistent value combinations
  at `helm template` time.
- Render-assertion runner (`moodle/tests/run.sh`) wired into CI.

## Spec
docs/superpowers/specs/2026-05-07-moodle-postgres-support-design.md

## Upgrade note
External-mariadb users (`db.enabled: false`) must add `db.mariadb.enabled: false`
to their values file. The validation guard fails `helm template` with an
actionable message if missed.

## Test plan
- [ ] CI green
- [ ] Live install on kind with zalando postgres-operator pre-installed
      reaches a fresh Moodle login page
EOF
)"
```

(If the user prefers to defer push/PR creation, Step 4 is optional — the work is complete after the CI step lands.)

---

## Summary of commits

After all 11 tasks the branch contains roughly these commits:

1. `test(moodle): scaffold helm-template assertion runner`
2. `feat(moodle): add db.type, db.mariadb.enabled, db.postgres.* values`
3. `feat(moodle): fail-fast validation guard for db.type misconfigs`
4. `feat(moodle): add moodle.dbDialect helper, drive MOODLE_DB_TYPE from db.type`
5. `feat(moodle): branch database helpers on db.type for postgres`
6. `feat(moodle): render postgresql.acid.zalan.do CR for db.type=postgres`
7. `feat(moodle): external-DB ExternalName port follows db.type`
8. `docs(moodle): NOTES.txt + README cover db.type=postgres path`
9. `docs(moodle): values_postgres.yaml.example for the postgres path`
10. (no commit if devops files all clean)
11. `ci: run moodle render assertions on every push`
