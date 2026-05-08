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

assert_renders "default internal mariadb" "$HERE/values/internal-mariadb.yaml"

# === yq assertions ===
# Added by later tasks. Example:
#   assert_yq "default MOODLE_DB_TYPE=mariadb" \
#     "$HERE/values/internal-mariadb.yaml" \
#     '... | select(.kind == "Deployment" and .metadata.labels.tier == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_TYPE") | .value' \
#     "mariadb"

assert_yq "default MOODLE_DB_TYPE=mariadb" \
  "$HERE/values/internal-mariadb.yaml" \
  'select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_TYPE") | .value' \
  "mariadb"

assert_yq_absent "no postgresql CR for default" \
  "$HERE/values/internal-mariadb.yaml" \
  'select((.apiVersion // "") == "acid.zalan.do/v1" and (.kind // "") == "postgresql")'

assert_yq_partial "postgres MOODLE_DB_TYPE=pgsql" \
  "$HERE/values/internal-postgres.yaml" \
  templates/deployment.yaml \
  '. | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_TYPE") | .value' \
  "pgsql"

# === Guard tests ===
# Added by later tasks. Example:
#   assert_fails_with "postgres + mariadb on" \
#     "$HERE/values/invalid-postgres-mariadb-on.yaml" \
#     "db.type=postgres requires db.mariadb.enabled=false"

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

assert_renders "external mariadb scenario" "$HERE/values/external-mariadb.yaml"

assert_yq_absent "external mariadb: no mariadb StatefulSet" \
  "$HERE/values/external-mariadb.yaml" \
  '. | select((.kind // "") == "StatefulSet" and ((.metadata.name // "") | test("mariadb")))'

assert_yq "external mariadb: ExternalName service on port 3306" \
  "$HERE/values/external-mariadb.yaml" \
  'select(.kind == "Service" and .spec.type == "ExternalName") | .spec.ports[0].port' \
  "3306"

# Internal-postgres helper outputs (CR not rendered yet — that's Task 6;
# the helpers must already produce the right values though, since the
# Deployment env block reads them).
assert_yq_partial "postgres internal: MOODLE_DB_HOST is clusterName" \
  "$HERE/values/internal-postgres.yaml" \
  templates/deployment.yaml \
  '. | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_HOST") | .value' \
  "release-name-moodle"

assert_yq_partial "postgres internal: MOODLE_DB_PORT=5432" \
  "$HERE/values/internal-postgres.yaml" \
  templates/deployment.yaml \
  '. | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_PORT") | .value' \
  "5432"

assert_yq_partial "postgres internal: MOODLE_DB_PASSWORD references operator secret" \
  "$HERE/values/internal-postgres.yaml" \
  templates/deployment.yaml \
  '. | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_PASSWORD") | .valueFrom.secretKeyRef.name' \
  "moodle.release-name-moodle.credentials.postgresql.acid.zalan.do"

assert_yq_partial "postgres internal: MOODLE_DB_PASSWORD secret key is 'password'" \
  "$HERE/values/internal-postgres.yaml" \
  templates/deployment.yaml \
  '. | select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_PASSWORD") | .valueFrom.secretKeyRef.key' \
  "password"

assert_renders "internal postgres scenario" "$HERE/values/internal-postgres.yaml"

assert_yq_exists "internal postgres: exactly one postgresql CR" \
  "$HERE/values/internal-postgres.yaml" \
  '. | select((.apiVersion // "") == "acid.zalan.do/v1" and (.kind // "") == "postgresql")'

assert_yq "internal postgres: CR name follows moodle.fullname" \
  "$HERE/values/internal-postgres.yaml" \
  '. | select((.kind // "") == "postgresql") | .metadata.name' \
  "release-name-moodle"

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

# zalando CRD requires every spec.resources.* value to be a string; YAML
# parses unit-less numbers (cpu: 1) as int and the operator rejects them
# at admission time. Pin the rendered type with `tag` so this can't
# regress silently. (`!!str` for strings, `!!int` for ints, etc.)
assert_yq "internal postgres: limits.cpu is rendered as string" \
  "$HERE/values/internal-postgres.yaml" \
  '. | select((.kind // "") == "postgresql") | .spec.resources.limits.cpu | tag' \
  "!!str"

assert_yq "internal postgres: requests.cpu is rendered as string" \
  "$HERE/values/internal-postgres.yaml" \
  '. | select((.kind // "") == "postgresql") | .spec.resources.requests.cpu | tag' \
  "!!str"

assert_yq_absent "internal postgres: no mariadb StatefulSet" \
  "$HERE/values/internal-postgres.yaml" \
  '. | select((.kind // "") == "StatefulSet" and ((.metadata.name // "") | test("mariadb")))'

assert_renders "external postgres scenario" "$HERE/values/external-postgres.yaml"

assert_yq "external postgres: ExternalName service on port 5432" \
  "$HERE/values/external-postgres.yaml" \
  'select(.kind == "Service" and .spec.type == "ExternalName") | .spec.ports[0].port' \
  "5432"

assert_yq "external postgres: MOODLE_DB_TYPE=pgsql" \
  "$HERE/values/external-postgres.yaml" \
  'select(.kind == "Deployment" and (.metadata.labels.tier // "") == "app") | .spec.template.spec.containers[0].env[] | select(.name == "MOODLE_DB_TYPE") | .value' \
  "pgsql"

assert_yq_absent "external postgres: no postgresql CR" \
  "$HERE/values/external-postgres.yaml" \
  '. | select((.kind // "") == "postgresql")'

if (( FAIL > 0 )); then
  echo
  echo "FAILED $FAIL  PASSED $PASS"
  exit 1
fi
echo
echo "PASSED $PASS  (no failures)"
