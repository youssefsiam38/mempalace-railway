# Railway template configuration

The template's exact configuration. Reproduce it from this file if it ever has to be rebuilt.

| | |
|---|---|
| Name | MemPalace |
| Code | `mempalace` |
| Template id | `b4922792-e848-458d-bc03-69b2afe4ef87` |
| Deploy URL | https://railway.com/deploy/mempalace |
| Category | AI/ML |
| Card description | Self-hosted AI memory server (MCP) with a private Qdrant, for agents. |
| Icon | `assets/icon.png` |
| Overview markdown | `marketplace/OVERVIEW.md` (Railway enforces its section headings) |

Generated values use Railway's `secret()` function: `hexN` is `${{secret(N, "abcdef0123456789")}}` and `alnumN` is
`${{secret(N, "a-zA-Z0-9")}}` spelled out. Alphanumeric passwords are used wherever a value is embedded in a
connection URL, so nothing needs percent-encoding. Images are referenced by tag, because the template generator
rejects digests; `UPSTREAM.md` records the digests.

## Services

### `qdrant`

| Field | Value |
|---|---|
| Source | `qdrant/qdrant:v1.19.1` |
| Public domain | none |
| Volume | `/qdrant/storage` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `QDRANT__SERVICE__HOST` | `::` |

### `mempalace`

| Field | Value |
|---|---|
| Source | `ghcr.io/youssefsiam38/mempalace-railway:1.0.0` |
| Public domain | target port 8765 |
| Volume | `/data` |
| Healthcheck | `/healthz`, timeout from `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `MEMPALACE_QDRANT_URL` | `http://${{qdrant.RAILWAY_PRIVATE_DOMAIN}}:6333` |
| `MEMPALACE_MCP_HTTP_TOKEN` | generated, alnum48 |
| `MEMPALACE_MCP_IDLE_HOURS` | `0` |
| `PORT` | `8765` |
| `RAILWAY_RUN_UID` | `0` |
| `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` | `300` |

## Notes

- **`PORT` must equal the server's listen port (8765).** Railway routes both the public edge and the health check
  to the port named by `PORT`. MemPalace's `serve --port` does not read `PORT`, so the template sets `PORT=8765`
  to match the `--port 8765` baked into the image's command and the public domain's target port.
- **`RAILWAY_RUN_UID=0`.** The MemPalace image runs as a non-root user; Railway mounts volumes as root, so this
  lets the process own its `/data` directory.
- **Qdrant binds `::`.** Railway's private network is IPv6; `QDRANT__SERVICE__HOST=::` makes Qdrant reachable at
  `qdrant.railway.internal:6333` (dual-stack on Linux).
- **`MEMPALACE_MCP_IDLE_HOURS=0`** disables the idle-exit watchdog (default 8 h) so the server stays up.
- **Auth:** `MEMPALACE_MCP_HTTP_TOKEN` (generated) is the bearer token required on every route except `/healthz`.
  Connect a client with `claude mcp add --transport http mempalace https://<domain>/mcp --header
  "Authorization: Bearer <token>"`. The health check path is `/healthz` (credential-free).
- Two volumes: the MemPalace `/data` (palace, config, embedding-model cache) and Qdrant `/qdrant/storage`
  (vectors). The embedding model downloads on the first write; `/healthz` is up immediately.
