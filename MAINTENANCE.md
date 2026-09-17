# Maintenance

## Releasing a new version

1. **Bump the upstream pins.** Get the new digests (see `UPSTREAM.md` for the commands) and update:
   - `images/mempalace/Dockerfile` — `ARG MEMPALACE_IMAGE=...@sha256:...`
   - `compose.yaml` — the `qdrant/qdrant` image pin
   - `UPSTREAM.md` and `_audit/spec_mempalace.py`
2. **Run the tests locally.**
   ```bash
   tests/static.sh
   tests/smoke.sh
   tests/persistence.sh
   ```
3. **Tag and push.** `git tag vX.Y.Z && git push --tags`. The `publish-image` workflow builds the wrapper, runs
   the tests against the candidate, and pushes `:X.Y.Z`, `:X.Y` and `:latest` to GHCR.
4. **Update the template** if the pinned image tag changed: set the mempalace service's image to the new tag and
   re-run the clean-room deploy + `tests/railway-smoke.sh` before publishing.

## Rebuilding the Railway template from scratch

The exact configuration is in `RAILWAY_TEMPLATE.md`. The generator spec is `_audit/spec_mempalace.py`; the kit in
`_audit/` (`tplkit.py`) builds a skeleton project, patches the template, and runs a clean-room deploy. Volumes,
domains and health checks are only set by `skeleton()`, so a change to any of those requires rebuilding from a
skeleton (not just patching).

## Gotchas worth remembering

- **`PORT` must equal the listen port (8765).** Railway routes the public edge *and* the health check to `PORT`.
  MemPalace's `serve --port` does not read `PORT`, so the template sets `PORT=8765` explicitly to match.
- **`RAILWAY_RUN_UID=0`.** The image runs as a non-root user; Railway mounts volumes as root, so without this the
  process cannot write `/data`.
- **Qdrant must bind `::`.** Railway's private network is IPv6; `QDRANT__SERVICE__HOST=::` makes qdrant reachable
  (dual-stack on Linux).
- **Idle watchdog.** `MEMPALACE_MCP_IDLE_HOURS=0` keeps the server from exiting after 8 idle hours.
- **First write is slow.** The embedding model downloads on the first `add_drawer`; `/healthz` is up immediately,
  so the health check passes well before that. `RAILWAY_HEALTHCHECK_TIMEOUT_SEC=300` gives cold starts room.
