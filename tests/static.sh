#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016
# Static validation: syntax, shellcheck, compose, image pins and security defaults. No Docker build.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
cd "$REPO_ROOT"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

section "syntax"
for f in tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "parses: $f"; else fail "syntax error: $f"; fi
done

section "shellcheck"
if command -v shellcheck >/dev/null; then
  if shellcheck -x -s bash tests/*.sh; then pass "shellcheck tests"; else fail "shellcheck tests"; fi
else
  echo "  SKIP  shellcheck not installed"
fi

section "compose"
if docker compose -f compose.yaml config -q; then pass "compose config"; else fail "compose config"; fi
cfg=$(docker compose -f compose.yaml config --format json)
assert_eq "two services" "mempalace qdrant" "$(jq -r '[.services | keys[]] | sort | join(" ")' <<<"$cfg")"
assert_eq "only mempalace publishes a port" "mempalace" "$(jq -r '[.services | to_entries[] | select(.value.ports) | .key] | join(" ")' <<<"$cfg")"
assert_eq "the port binds to loopback" "127.0.0.1" "$(jq -r '[.services.mempalace.ports[]? | .host_ip] | join(" ")' <<<"$cfg")"
assert_eq "the mempalace data volume is mounted" "/data" "$(jq -r '[.services.mempalace.volumes[]? | .target] | join(" ")' <<<"$cfg")"
assert_eq "the qdrant storage volume is mounted" "/qdrant/storage" "$(jq -r '[.services.qdrant.volumes[]? | .target] | join(" ")' <<<"$cfg")"
assert_contains "qdrant is pinned by tag and digest" '@sha256:[0-9a-f]\{64\}$' "$(jq -r '.services.qdrant.image' <<<"$cfg")"
assert_eq "qdrant binds :: for the IPv6 private network" "::" "$(jq -r '.services.qdrant.environment.QDRANT__SERVICE__HOST' <<<"$cfg")"
assert_eq "the idle watchdog is disabled so the server stays up" "0" "$(jq -r '.services.mempalace.environment.MEMPALACE_MCP_IDLE_HOURS' <<<"$cfg")"
assert_contains "the qdrant backend URL is set" '^http://qdrant:6333$' "$(jq -r '.services.mempalace.environment.MEMPALACE_QDRANT_URL' <<<"$cfg")"

section "image pins"
df=images/mempalace/Dockerfile
assert_contains "mempalace base pinned by digest" '^ARG MEMPALACE_IMAGE=.*@sha256:[0-9a-f]\{64\}$' "$(grep '^ARG MEMPALACE_IMAGE=' "$df")"
assert_contains "the default command runs the HTTP serve mode" '"serve"' "$(grep '^CMD' "$df")"
assert_contains "serve binds all interfaces" '"0.0.0.0"' "$(grep '^CMD' "$df")"
assert_contains "serve uses the qdrant backend" '"qdrant"' "$(grep '^CMD' "$df")"

section "auth posture"
# The bearer token must never be baked into an image layer or a tracked file as a real value; it is supplied by
# the template as a generated secret. The compose default is clearly a placeholder.
assert_contains "compose token is an obvious placeholder" 'please-change' "$(jq -r '.services.mempalace.environment.MEMPALACE_MCP_HTTP_TOKEN' <<<"$cfg")"
assert_not_contains "no insecure-no-token override is set in compose" 'MEMPALACE_MCP_HTTP_ALLOW_INSECURE_NO_TOKEN' "$cfg"

section "secrets hygiene"
mapfile -t tracked < <(git ls-files 2>/dev/null | grep . || find . -type f -not -path './.git/*' -not -path './test-output/*')
if [ "${#tracked[@]}" -gt 0 ] && grep -lE '(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "${tracked[@]}" 2>/dev/null; then
  fail "a credential-shaped string is in the repository"
else
  pass "no credential-shaped strings in ${#tracked[@]} files"
fi

summary
