# MemPalace on Railway

A one-click [Railway](https://railway.com) template that runs [MemPalace](https://github.com/MemPalace/mempalace)
as a **remote team memory server**: an MCP-over-HTTP endpoint your AI coding agents (Claude Code, Codex, and other
MCP clients) connect to so they share one persistent, self-hosted memory. Vectors are stored in a bundled
[Qdrant](https://github.com/qdrant/qdrant); embeddings are produced locally inside the MemPalace container, so
your memory text and vectors never leave your Railway project.

This is a community-maintained template and is not affiliated with the MemPalace project.

- **Template image:** `ghcr.io/youssefsiam38/mempalace-railway` (the official MemPalace image, pinned by digest,
  set to run the HTTP server)
- **Upstream:** MemPalace (MIT) + Qdrant (Apache-2.0) — see [UPSTREAM.md](UPSTREAM.md)

## What you get

- Two services: **mempalace** (public HTTPS MCP endpoint) and **qdrant** (private vector store, on its own volume).
- A **generated bearer token** (`MEMPALACE_MCP_HTTP_TOKEN`). Every request except the liveness probe requires it.
- Persistent memory: the palace metadata on the mempalace `/data` volume, the vectors on the qdrant volume.
- No login page and no UI — it is an API for MCP clients. There is nothing for a stranger to sign up to.

## Deploy

1. Click **Deploy on Railway** and wait for both services to go healthy.
2. Open the **mempalace** service → **Variables** and copy `MEMPALACE_MCP_HTTP_TOKEN`.
3. Note the public domain of the mempalace service (e.g. `mempalace-production-xxxx.up.railway.app`).

## Connect a client

Point any MCP-over-HTTP client at `https://<your-domain>/mcp` with the bearer token:

```bash
claude mcp add --transport http mempalace https://<your-domain>/mcp \
  --header "Authorization: Bearer <MEMPALACE_MCP_HTTP_TOKEN>"
```

```bash
codex mcp add --transport http mempalace https://<your-domain>/mcp \
  --header "Authorization: Bearer <MEMPALACE_MCP_HTTP_TOKEN>"
```

Liveness (no token) for a quick check:

```bash
curl https://<your-domain>/healthz    # -> ok
```

Every teammate uses the **same** URL and token; each agent's writes are shared through the one palace.

## Security

- The bearer token is the single credential and grants full read/write to the shared memory. Treat it like a
  password; rotate it by changing `MEMPALACE_MCP_HTTP_TOKEN` on the service.
- Qdrant has **no public domain** — it is only reachable by the mempalace service over Railway's private network.
- TLS is terminated by Railway's edge; the container speaks plaintext HTTP internally.
- Read-only mode and other tuning: see [ARCHITECTURE.md](ARCHITECTURE.md) and [SECURITY.md](SECURITY.md).

## Repository layout

| Path | What |
|---|---|
| `images/mempalace/Dockerfile` | The wrapper image: upstream pinned by digest, default command = HTTP serve |
| `compose.yaml` | Local test topology mirroring the Railway service graph |
| `tests/` | Static, smoke (MCP round-trip), persistence, and live (HTTPS) tests |
| `marketplace/OVERVIEW.md` | The marketplace overview shown on the template page |
| `RAILWAY_TEMPLATE.md` | The exact published template configuration |
| `UPSTREAM.md` · `SECURITY.md` · `ARCHITECTURE.md` · `MAINTENANCE.md` | Reference docs |

## Local development

```bash
docker compose up --build         # bring up mempalace + qdrant
tests/smoke.sh                    # MCP handshake + store/search round-trip
tests/persistence.sh             # memory survives a restart
```

## Licence

The template's own files are MIT (`LICENSE`). MemPalace and Qdrant keep their own licences; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
