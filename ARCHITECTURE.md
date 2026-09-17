# Architecture

## Service graph

```
                 Railway edge (HTTPS, TLS)
                          │
                          ▼
        ┌──────────────────────────────────┐
        │  mempalace  (public domain :8765) │   volume: /data  (palace + config + model cache)
        │  remote HTTP MCP server           │
        │  - GET  /healthz   (no auth)      │
        │  - POST /mcp       (Bearer token) │
        └───────────────┬──────────────────┘
                        │  Railway private network (IPv6, encrypted)
                        ▼
        ┌──────────────────────────────────┐
        │  qdrant  (no public domain :6333) │   volume: /qdrant/storage  (vectors)
        │  bound on :: (dual-stack)         │
        └──────────────────────────────────┘
```

Embeddings are computed **inside** the mempalace container (default model `minilm`, ~80 MB, downloaded to the
`/data` cache on first write). Only your own Qdrant ever receives the vectors and text.

## The mempalace service

- Image: the official `ghcr.io/mempalace/mempalace` pinned by digest. The wrapper only changes the default
  command to `serve --host 0.0.0.0 --port 8765 --backend qdrant`, which upstream's entrypoint forwards to
  `mempalace serve`, which runs `mempalace-mcp --transport http`.
- **Port:** listens on `8765`. The template sets `PORT=8765`, the public domain's target port is `8765`, and the
  health check path is `/healthz` — all aligned so Railway routes traffic and health checks to the right port.
- **Auth:** `MEMPALACE_MCP_HTTP_TOKEN` (generated) is required for every route except `/healthz`. On a non-loopback
  bind upstream disables Host pinning, so the Railway domain in the `Host` header is accepted; a browser `Origin`
  is still rejected (MCP clients send none). The token rides in the environment, never on the command line.
- **Idle watchdog:** upstream exits after `MEMPALACE_MCP_IDLE_HOURS` of inactivity (default 8). The template sets
  it to `0` so the server stays up on Railway.
- **Volume:** `/data` holds the palace (`~/.config/mempalace/palace` or `~/.mempalace`), config, and the embedding
  model cache. `HOME=/data` in the image. The image runs as a non-root user, so the template sets
  `RAILWAY_RUN_UID=0` (Railway mounts volumes as root; this lets the process own its data directory).

## The qdrant service

- Image: the official `qdrant/qdrant` pinned by digest, run as-is.
- **Bind:** `QDRANT__SERVICE__HOST=::` so it is reachable over Railway's IPv6 private network (dual-stack on Linux,
  so local IPv4 Docker works too). It has **no public domain**.
- **Volume:** `/qdrant/storage` holds the collections and their vectors.
- mempalace reaches it at `http://${qdrant.RAILWAY_PRIVATE_DOMAIN}:6333` over REST.

## Data flow of one memory

1. A client calls `tools/call` → `mempalace_add_drawer` on `POST /mcp` with the bearer token.
2. mempalace embeds the content locally and upserts the vector + payload into Qdrant.
3. `mempalace_search` embeds the query and runs a vector search in Qdrant, returning matching drawers.

## Backend choice

MemPalace also supports a `pgvector` (PostgreSQL) backend. This template uses **Qdrant**, matching upstream's
documented team-server topology; it is the best-benchmarked default and keeps the vector store independent of any
relational database.
