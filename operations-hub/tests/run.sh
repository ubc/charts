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

assert_yq_partial "autofetch: init container present" \
  "$HERE/values/saml-autofetch.yaml" "templates/deployment.yaml" \
  '.spec.template.spec.initContainers[0].name' "fetch-idp-metadata"

assert_yq_partial "autofetch: init container uses the app image" \
  "$HERE/values/saml-autofetch.yaml" "templates/deployment.yaml" \
  '.spec.template.spec.initContainers[0].image == .spec.template.spec.containers[0].image' \
  "true"

assert_yq_partial "autofetch: URL passed to init container" \
  "$HERE/values/saml-autofetch.yaml" "templates/deployment.yaml" \
  '.spec.template.spec.initContainers[0].env[] | select(.name == "IDP_METADATA_URL") | .value' \
  "https://authentication.stg.id.ubc.ca/idp/shibboleth"

assert_yq_partial "autofetch: idp volume is an emptyDir" \
  "$HERE/values/saml-autofetch.yaml" "templates/deployment.yaml" \
  '[.spec.template.spec.volumes[] | select(.name == "operations-hub-saml-idp") | .emptyDir] | length' \
  "1"

assert_yq_partial "static idp: no init container" \
  "$HERE/values/saml-static-idp.yaml" "templates/deployment.yaml" \
  '[.spec.template.spec.initContainers // []] | flatten | length' "0"

assert_yq_exists "autofetch: script ConfigMap rendered" \
  "$HERE/values/saml-autofetch.yaml" \
  'select(.kind == "ConfigMap" and (.metadata.name | test("saml-fetch$")))'

assert_yq_absent "saml-off: no script ConfigMap" \
  "$HERE/values/saml-off.yaml" \
  'select(.kind == "ConfigMap" and (.metadata.name | test("saml-fetch$")))'

assert_yq_partial "autofetch: init container mounts idp dir writable" \
  "$HERE/values/saml-autofetch.yaml" "templates/deployment.yaml" \
  '.spec.template.spec.initContainers[0].volumeMounts[] | select(.name == "operations-hub-saml-idp") | .readOnly // false' \
  "false"

assert_yq_partial "autofetch: app mounts idp dir read-only" \
  "$HERE/values/saml-autofetch.yaml" "templates/deployment.yaml" \
  '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "operations-hub-saml-idp") | .readOnly' \
  "true"

assert_yq_partial "autofetch: entity id is passed to init container" \
  "$HERE/values/saml-autofetch.yaml" "templates/deployment.yaml" \
  '.spec.template.spec.initContainers[0].env[] | select(.name == "IDP_ENTITY_ID") | .value' \
  "https://authentication.stg.id.ubc.ca"

assert_yq_partial "autofetch: init writes exactly where the app reads" \
  "$HERE/values/saml-autofetch.yaml" "templates/deployment.yaml" \
  '(.spec.template.spec.initContainers[0].env[] | select(.name=="IDP_OUTPUT_PATH") | .value) == (.spec.template.spec.containers[0].env[] | select(.name=="SAML_IDP_METADATA_PATH") | .value)' \
  "true"

assert_yq_partial "autofetch with baseline: IDP_BASELINE_PATH set" \
  "$HERE/values/saml-autofetch.yaml" "templates/deployment.yaml" \
  '[.spec.template.spec.initContainers[0].env[] | select(.name == "IDP_BASELINE_PATH")] | length' "1"

assert_yq_partial "autofetch with baseline: baseline volume mounted in init" \
  "$HERE/values/saml-autofetch.yaml" "templates/deployment.yaml" \
  '[.spec.template.spec.initContainers[0].volumeMounts[] | select(.name == "operations-hub-saml-baseline")] | length' "1"

assert_yq_partial "autofetch without baseline: no IDP_BASELINE_PATH" \
  "$HERE/values/saml-autofetch-no-baseline.yaml" "templates/deployment.yaml" \
  '[.spec.template.spec.initContainers[0].env[] | select(.name == "IDP_BASELINE_PATH")] | length' "0"

assert_yq_partial "autofetch without baseline: no baseline volume" \
  "$HERE/values/saml-autofetch-no-baseline.yaml" "templates/deployment.yaml" \
  '[.spec.template.spec.volumes[] | select(.name == "operations-hub-saml-baseline")] | length' "0"

if (( FAIL > 0 )); then
  echo
  echo "FAILED $FAIL  PASSED $PASS"
  exit 1
fi
echo
echo "PASSED $PASS  (no failures)"
