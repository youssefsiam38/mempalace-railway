#!/usr/bin/env bash
# shellcheck disable=SC2015
# Shared helpers for mempalace-railway tests. Source this file; do not execute it.
# The bearer token is never echoed. Only names, counts, and pass/fail results are printed.

: "${APP_URL:=http://localhost:${MEMPALACE_TEST_PORT:-18765}}"
: "${TEST_TIMEOUT:=300}"
# The token the tests authenticate with. Locally this matches compose's default; over HTTPS it is read from a
# file (railway-smoke.sh). Never printed.
: "${MEMPALACE_TOKEN:=${MEMPALACE_TEST_TOKEN:-local-test-only-bearer-token-please-change}}"

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
export TEST_TMP
_PASS=0; _FAIL=0

pass() { _PASS=$((_PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { _FAIL=$((_FAIL+1)); printf '  FAIL  %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$*"; }
summary() { printf '\n%d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

assert_eq() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1: expected [$2] got [$3]"; fi; }
assert_contains() { if grep -q -- "$2" <<<"$3"; then pass "$1"; else fail "$1: missing [$2]"; fi; }
assert_not_contains() { if grep -q -- "$2" <<<"$3"; then fail "$1: found forbidden [$2]"; else pass "$1"; fi; }

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$@" || true; }

wait_for_code() {
  local url=$1 want=$2 timeout=${3:-$TEST_TIMEOUT} start code
  start=$(date +%s)
  while :; do
    code=$(http_code "$url")
    [ "$code" = "$want" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for %s -> %s (last %s)\n' "$url" "$want" "$code" >&2; return 1; fi
    sleep 3
  done
}

compose() { docker compose -f "$REPO_ROOT/compose.yaml" "$@"; }

# mcp_raw BODY [--no-auth|--bad-auth] -> prints the raw HTTP body of a POST /mcp JSON-RPC call.
mcp_raw() {
  local body=$1 mode=${2:-auth} auth=(-H "Authorization: Bearer $MEMPALACE_TOKEN")
  case "$mode" in
    --no-auth)  auth=() ;;
    --bad-auth) auth=(-H "Authorization: Bearer definitely-not-the-token") ;;
  esac
  curl -s --max-time 240 -X POST "$APP_URL/mcp" \
    "${auth[@]}" -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    --data "$body"
}

# mcp_code BODY [mode] -> prints the HTTP status of a POST /mcp call (for auth checks).
mcp_code() {
  local body=$1 mode=${2:-auth} auth=(-H "Authorization: Bearer $MEMPALACE_TOKEN")
  case "$mode" in
    --no-auth)  auth=() ;;
    --bad-auth) auth=(-H "Authorization: Bearer definitely-not-the-token") ;;
  esac
  curl -s -o /dev/null -w '%{http_code}' --max-time 60 -X POST "$APP_URL/mcp" \
    "${auth[@]}" -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    --data "$body" || true
}

# mcp_call ID NAME ARGS_JSON -> tools/call; prints the inner tool text payload (result.content[0].text).
mcp_call() {
  local id=$1 name=$2 args=$3
  mcp_raw "$(jq -nc --arg id "$id" --arg n "$name" --argjson a "$args" \
    '{jsonrpc:"2.0", id:($id|tonumber), method:"tools/call", params:{name:$n, arguments:$a}}')" \
    | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); r=d.get('result',{})
    c=r.get('content')
    print(c[0].get('text','') if c else json.dumps(d))
except Exception as e:
    print('')"
}
