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

assert_fails_with "autofetch with whitespace-only idpEntityId is rejected" \
  "$HERE/values/invalid-autofetch-blank-entity-id.yaml" \
  "app.saml.idpEntityId is required"

assert_fails_with "autofetch with null idpEntityId is rejected" \
  "$HERE/values/invalid-autofetch-null-entity-id.yaml" \
  "app.saml.idpEntityId is required"

assert_yq_partial "static idp: SAML_IDP_METADATA_PATH points at saml-idp mount" \
  "$HERE/values/saml-static-idp.yaml" "templates/deployment.yaml" \
  '.spec.template.spec.containers[0].env[] | select(.name == "SAML_IDP_METADATA_PATH") | .value' \
  "/app/instance/saml-idp/idp-metadata.xml"

assert_yq_partial "static idp: dedicated volume is mounted" \
  "$HERE/values/saml-static-idp.yaml" "templates/deployment.yaml" \
  '[.spec.template.spec.containers[0].volumeMounts[] | select(.name == "operations-hub-saml-idp")] | length' \
  "1"

assert_yq_partial "saml-off: no idp volume when no metadata source" \
  "$HERE/values/saml-off.yaml" "templates/deployment.yaml" \
  '[.spec.template.spec.volumes[] | select(.name == "operations-hub-saml-idp")] | length' \
  "0"

assert_yq_partial "disabled: no idp volume even when idpMetadata set" \
  "$HERE/values/saml-disabled-with-idp.yaml" "templates/deployment.yaml" \
  '[.spec.template.spec.volumes[] | select(.name == "operations-hub-saml-idp")] | length' \
  "0"

assert_yq_partial "static idp: volume exists and is configMap-backed" \
  "$HERE/values/saml-static-idp.yaml" "templates/deployment.yaml" \
  '[.spec.template.spec.volumes[] | select(.name == "operations-hub-saml-idp") | .configMap] | length' \
  "1"

if (( FAIL > 0 )); then
  echo
  echo "FAILED $FAIL  PASSED $PASS"
  exit 1
fi
echo
echo "PASSED $PASS  (no failures)"
