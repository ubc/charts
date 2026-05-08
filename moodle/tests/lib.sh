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
  count=$(helm template "$RELEASE" "$CHART" -f "$values" 2>/dev/null | yq -s "[.[] | $expr] | length" 2>/dev/null || echo 0)
  if [[ "${count:-0}" -ge 1 ]]; then
    echo "PASS [exists] $name"; PASS=$((PASS+1))
  else
    echo "FAIL [exists] $name -- no docs matched"; FAIL=$((FAIL+1))
  fi
}

assert_yq_absent() {
  local name=$1 values=$2 expr=$3
  local count
  count=$(helm template "$RELEASE" "$CHART" -f "$values" 2>/dev/null | yq -s "[.[] | $expr] | length" 2>/dev/null || echo 0)
  if [[ "${count:-0}" -eq 0 ]]; then
    echo "PASS [absent] $name"; PASS=$((PASS+1))
  else
    echo "FAIL [absent] $name -- expected 0 matches, got $count"; FAIL=$((FAIL+1))
  fi
}

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
