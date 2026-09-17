# Marketplace audit

A record of the diligence behind publishing this template.

## Identity

- Template: **MemPalace** (remote team memory server, MCP over HTTP).
- Upstream: [MemPalace/mempalace](https://github.com/MemPalace/mempalace), MIT, active.
- Vector store: [qdrant/qdrant](https://github.com/qdrant/qdrant), Apache-2.0, official image.

## Licence

- MemPalace is MIT (`licenses/MEMPALACE-LICENSE`); redistribution as a template is permitted. The application is
  used unmodified from the official image; the wrapper only sets the default command.
- Qdrant is Apache-2.0; used unmodified from the official image.
- No "competing use"/source-available restrictions apply. See `THIRD_PARTY_NOTICES.md`.

## Security review

- **No public multi-tenant surface.** The service is a single-token API. There is no registration, no UI, and no
  first-user race to close — the bearer token is the entire boundary and is generated per deploy.
- **Bearer token enforced.** Every route except `/healthz` requires `Authorization: Bearer <token>` (verified in
  the smoke and live tests: `401` without/with a wrong token, `200` with the right one). The insecure-no-token
  override is never set.
- **Secret hygiene.** The token is passed via the environment (never argv), never printed by the tests or logged by
  the wrapper, and the static test greps the tree for credential-shaped strings.
- **Qdrant is private.** No public domain; reachable only over the private network.
- **Reproducible.** Both images pinned by digest.

## Reproducibility & tests

- `tests/static.sh` (23 checks): syntax, shellcheck, compose shape, digest pins, port/bind/idle/auth posture,
  secret scan.
- `tests/smoke.sh` (11 checks): liveness, bearer enforcement, MCP handshake, store→embed→vector-search round-trip.
- `tests/persistence.sh` (4 checks): a stored memory is still searchable after a full restart with volumes kept.
- `tests/railway-smoke.sh`: the same MCP flows over HTTPS against the deployed template.
- CI runs static + build + smoke + persistence on every push; the publish workflow re-tests the candidate image
  before pushing it to GHCR.

## Deploy-time inputs

- `MEMPALACE_MCP_HTTP_TOKEN` — generated (the bearer token; copy it to connect clients).
- Everything else is fixed by the template (Qdrant URL, port, health check, volumes, IPv6 bind, run-as-root, idle
  watchdog off). No required human input beyond clicking deploy.

## Verdict

Shippable. A self-contained, reproducible, token-guarded MemPalace team server with a bundled private Qdrant,
verified end-to-end on a live Railway deployment.
