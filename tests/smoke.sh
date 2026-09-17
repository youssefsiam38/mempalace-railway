#!/usr/bin/env bash
# shellcheck disable=SC2015
# Smoke test: build+run the stack (or reuse a running one), then exercise the MemPalace remote MCP server over
# HTTP the way a real MCP client does — liveness, bearer enforcement, protocol handshake, and a full
# store -> embed -> vector-search round-trip backed by Qdrant.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

STARTED=0
if [ "${MEMPALACE_REUSE_STACK:-0}" != "1" ]; then
  section "bring the stack up"
  compose up -d --build >/dev/null 2>&1 || die "compose up failed"
  STARTED=1
  trap 'compose logs --no-color --tail 100 || true; [ "$STARTED" = 1 ] && compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"' EXIT
else
  trap 'rm -rf "$TEST_TMP"' EXIT
fi

section "liveness"
wait_for_code "$APP_URL/healthz" 200 180 && pass "/healthz returns 200 (no auth)" || die "server never became healthy"
assert_eq "/healthz body is ok" "ok" "$(curl -s --max-time 10 "$APP_URL/healthz" | tr -d '\n')"

section "the bearer token is enforced"
assert_eq "POST /mcp without a token is rejected" "401" \
  "$(mcp_code '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' --no-auth)"
assert_eq "POST /mcp with a wrong token is rejected" "401" \
  "$(mcp_code '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' --bad-auth)"

section "MCP protocol handshake"
init=$(mcp_raw '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"0"}}}')
assert_contains "initialize returns the mempalace server info" '"name": "mempalace"' "$init"
tools=$(mcp_raw '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')
assert_contains "tools/list advertises the store tool" "mempalace_add_drawer" "$tools"
assert_contains "tools/list advertises the search tool" "mempalace_search" "$tools"

section "store -> search round-trip (Qdrant backend + local embeddings)"
marker="smoke-$(date +%s)"
content="Decision $marker: the team standardised on gRPC for internal service-to-service calls."
stored=$(mcp_call 3 mempalace_add_drawer "$(jq -nc --arg c "$content" '{wing:"smoke", room:"decisions", content:$c}')")
assert_contains "a memory is stored (drawer created)" '"success": true' "$stored"
assert_contains "the new drawer reports its id" "drawer_smoke_decisions" "$stored"
# The embedding model downloads on the first write; give the search a generous window.
found=$(mcp_call 4 mempalace_search '{"query":"what did the team standardise on for internal calls","limit":5}')
assert_contains "the stored memory is found by semantic search" "$marker" "$found"

section "an authenticated read tool works"
status=$(mcp_call 5 mempalace_status '{}')
[ -n "$status" ] && pass "mempalace_status responds" || fail "mempalace_status returned nothing"

summary
