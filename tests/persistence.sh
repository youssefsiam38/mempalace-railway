#!/usr/bin/env bash
# shellcheck disable=SC2015
# Persistence: memories live in Qdrant (the qdrant volume) with their metadata in the palace (the mempalace
# /data volume). Store a marker memory, take the stack down keeping the volumes, bring it back, and confirm the
# memory is still searchable. Run after smoke.sh, or standalone (it brings the stack up itself).
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'compose logs --no-color --tail 100 || true; compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"' EXIT

section "bring the stack up"
compose up -d --build >/dev/null 2>&1 || die "compose up failed"
wait_for_code "$APP_URL/healthz" 200 180 || die "server never became healthy"

section "before restart"
marker="persist-$(date +%s)"
content="Persistent note $marker: the archive lives in bucket eu-central-1 and rotates every 90 days."
stored=$(mcp_call 1 mempalace_add_drawer "$(jq -nc --arg c "$content" '{wing:"persist", room:"decisions", content:$c}')")
assert_contains "stored a marker memory" '"success": true' "$stored"
found=$(mcp_call 2 mempalace_search '{"query":"where does the archive live and how often does it rotate","limit":5}')
assert_contains "the marker memory is searchable before the restart" "$marker" "$found"

section "full restart (volumes preserved)"
compose down >/dev/null 2>&1
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_code "$APP_URL/healthz" 200 180 && pass "healthy again after restart" || die "not healthy after the restart"

section "after restart"
found=$(mcp_call 3 mempalace_search '{"query":"where does the archive live and how often does it rotate","limit":5}')
assert_contains "the marker memory survived the restart" "$marker" "$found"

summary
