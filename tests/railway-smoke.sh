#!/usr/bin/env bash
# shellcheck disable=SC2015
# Live test of a deployed template: the MCP flows the local smoke covers, over HTTPS.
#
#   MEMPALACE_TOKEN_FILE=./token tests/railway-smoke.sh https://<app-domain>
#
# The bearer token is read from a file (never an argument, never printed). Rerunnable: it writes one marker
# memory per run.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
[ $# -ge 1 ] || { sed -n '3,6p' "$0"; exit 2; }
APP_URL=${1%/}; export APP_URL
: "${MEMPALACE_TOKEN_FILE:?set MEMPALACE_TOKEN_FILE to a file holding the bearer token}"
MEMPALACE_TOKEN=$(tr -d '\n' < "$MEMPALACE_TOKEN_FILE"); export MEMPALACE_TOKEN
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

section "availability over HTTPS"
wait_for_code "$APP_URL/healthz" 200 300 && pass "/healthz returns 200 over HTTPS (no auth)" || die "not healthy"

section "the bearer token is enforced over HTTPS"
assert_eq "POST /mcp without a token is rejected" "401" \
  "$(mcp_code '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' --no-auth)"
assert_eq "POST /mcp with a wrong token is rejected" "401" \
  "$(mcp_code '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' --bad-auth)"

section "MCP handshake over HTTPS"
init=$(mcp_raw '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"railway-smoke","version":"0"}}}')
assert_contains "initialize returns the mempalace server info" '"name": "mempalace"' "$init"
tools=$(mcp_raw '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')
assert_contains "tools/list advertises the store and search tools" "mempalace_search" "$tools"

section "store -> search round-trip over HTTPS"
marker="live-$(date +%s)"
content="Live note $marker: the on-call rotation handoff happens every Monday at 10:00 UTC."
stored=$(mcp_call 3 mempalace_add_drawer "$(jq -nc --arg c "$content" '{wing:"live", room:"decisions", content:$c}')")
assert_contains "a memory is stored over HTTPS" '"success": true' "$stored"
found=$(mcp_call 4 mempalace_search '{"query":"when is the on-call handoff","limit":5}')
assert_contains "the stored memory is found by semantic search" "$marker" "$found"

summary
