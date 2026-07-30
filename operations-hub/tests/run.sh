#!/usr/bin/env bash
# Render-assertions for the operations-hub chart.
# Requires: helm 3, yq v4 (mikefarah).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
CHART="$HERE/.."

# shellcheck source=lib.sh
source "$HERE/lib.sh"

PASS=0
FAIL=0

assert_renders "saml on, autofetch off" "$HERE/values/saml-off.yaml"

assert_fails_with "autofetch without idpEntityId is rejected" \
  "$HERE/values/invalid-autofetch-no-entity-id.yaml" \
  "app.saml.idpEntityId is required"

if (( FAIL > 0 )); then
  echo
  echo "FAILED $FAIL  PASSED $PASS"
  exit 1
fi
echo
echo "PASSED $PASS  (no failures)"
