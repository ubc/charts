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
