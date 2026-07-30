#!/usr/bin/env bash
# Behavioural tests for files/fetch-idp-metadata.py.
#
# Needs python3-saml, which ships in the application image but not on a CI runner
# (it wants xmlsec system libraries). When the import is unavailable these are
# SKIPPED loudly rather than silently passing. To run them for real:
#   kubectl -n ltic-operations-hub exec <pod> -i -- bash < operations-hub/tests/test-fetch.sh
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="${FETCH_SCRIPT:-$HERE/../files/fetch-idp-metadata.py}"
PASS=0; FAIL=0

if ! python3 -c 'import onelogin.saml2' 2>/dev/null; then
  echo "SKIP: python3-saml unavailable -- run inside the application image."
  echo "SKIPPED (not a pass)"
  exit 0
fi

URL="https://authentication.stg.id.ubc.ca/idp/shibboleth"
ENTITY="https://authentication.stg.id.ubc.ca"

check() { # name expected_exit actual_exit
  if [[ "$2" == "$3" ]]; then echo "PASS $1"; PASS=$((PASS+1));
  else echo "FAIL $1 -- expected exit $2, got $3"; FAIL=$((FAIL+1)); fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
printf '<baseline/>' > "$WORK/baseline.xml"

# 1. Happy path: real staging IdP
IDP_METADATA_URL="$URL" IDP_ENTITY_ID="$ENTITY" IDP_OUTPUT_PATH="$WORK/out1.xml" \
  python3 "$SCRIPT"; check "happy path exits 0" 0 $?
if grep -q "EntityDescriptor" "$WORK/out1.xml" 2>/dev/null; then
  echo "PASS happy path wrote metadata"; PASS=$((PASS+1))
else
  echo "FAIL happy path did not write metadata"; FAIL=$((FAIL+1))
fi

# 2. Unreachable host falls back
IDP_METADATA_URL="https://127.0.0.1:1/nope" IDP_ENTITY_ID="$ENTITY" \
  IDP_FETCH_TIMEOUT=2 IDP_OUTPUT_PATH="$WORK/out2.xml" \
  IDP_BASELINE_PATH="$WORK/baseline.xml" python3 "$SCRIPT"; check "unreachable falls back" 0 $?
grep -q "baseline" "$WORK/out2.xml" \
  && { echo "PASS fallback content used"; PASS=$((PASS+1)); } \
  || { echo "FAIL fallback content not used"; FAIL=$((FAIL+1)); }

# 3. entityId mismatch falls back
IDP_METADATA_URL="$URL" IDP_ENTITY_ID="https://wrong.example" \
  IDP_OUTPUT_PATH="$WORK/out3.xml" IDP_BASELINE_PATH="$WORK/baseline.xml" \
  python3 "$SCRIPT"; check "entityId mismatch falls back" 0 $?

# 4. Malformed XML falls back
printf 'not xml at all' > "$WORK/bad.xml"
IDP_METADATA_URL="file://$WORK/bad.xml" IDP_ENTITY_ID="$ENTITY" \
  IDP_OUTPUT_PATH="$WORK/out4.xml" IDP_BASELINE_PATH="$WORK/baseline.xml" \
  python3 "$SCRIPT"; check "malformed falls back" 0 $?

# 5. Failure with no baseline is fatal
IDP_METADATA_URL="https://127.0.0.1:1/nope" IDP_ENTITY_ID="$ENTITY" \
  IDP_FETCH_TIMEOUT=2 IDP_OUTPUT_PATH="$WORK/out5.xml" python3 "$SCRIPT"
check "no baseline exits 1" 1 $?

echo
if (( FAIL > 0 )); then echo "FAILED $FAIL  PASSED $PASS"; exit 1; fi
echo "PASSED $PASS  (no failures)"
