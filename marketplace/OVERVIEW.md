# Deploy and Host MemPalace on Railway

MemPalace is an open-source AI memory system: a persistent, self-hosted "palace" your AI coding agents write to and
recall from over the Model Context Protocol (MCP). This template runs MemPalace as a **remote team server** — one
shared memory that Claude Code, Codex and other MCP clients across your team connect to over HTTPS. It is a
community-maintained template and is not affiliated with the MemPalace project.

## About Hosting MemPalace

MemPalace's team server speaks MCP over HTTP and stores its vectors in Qdrant, producing embeddings locally so your
memory text and vectors never leave the deployment. Exposed naively it is a plaintext endpoint whose bearer token is
the only thing standing between the internet and full read/write access to your memory, and it exits after a few
idle hours by default.

This template runs MemPalace on Railway with a bundled private Qdrant, generates a strong bearer token and requires
it on every route except the liveness probe, keeps Qdrant off the public internet, disables the idle-exit watchdog
so the server stays up, and wires the port, health check and volumes correctly (including the IPv6 private-network
bind and the non-root volume permission). Both services run from their official images, pinned by digest.

## Common Use Cases

- A shared, self-hosted long-term memory for a team of AI coding agents (Claude Code, Codex, and other MCP clients).
- A private memory backend where embeddings and data stay inside your own infrastructure.
- A persistent knowledge store that survives restarts and redeploys, backed by Qdrant.

## Dependencies for MemPalace Hosting

- Nothing external — Qdrant is bundled, and embeddings are computed inside the MemPalace container.

### Deployment Dependencies

- MemPalace: https://github.com/MemPalace/mempalace (MIT)
- Qdrant: https://github.com/qdrant/qdrant (Apache-2.0, official Docker image)
- Template repository, image and tests: https://github.com/youssefsiam38/mempalace-railway

### Implementation Details

MemPalace runs upstream's official image, pinned by digest, with the default command set to the remote HTTP MCP
server (`serve --host 0.0.0.0 --port 8765 --backend qdrant`). A generated `MEMPALACE_MCP_HTTP_TOKEN` guards every
route except `/healthz`; the token is passed through the environment, never the command line. Qdrant runs from its
official image with no public domain, bound on `::` for Railway's IPv6 private network, on its own volume. The
MemPalace `/data` volume holds the palace, config and embedding-model cache, with `RAILWAY_RUN_UID=0` so the
non-root process can own it, and `MEMPALACE_MCP_IDLE_HOURS=0` keeps the server from exiting when idle.

Tested in CI and on a live deployment of this template: liveness is public, the bearer token is enforced, the MCP
handshake works, a memory is stored and then found by semantic search through Qdrant, and memories survive a
redeploy.

After deploying, copy `MEMPALACE_MCP_HTTP_TOKEN` from the mempalace service's variables and connect a client:
`claude mcp add --transport http mempalace https://<your-domain>/mcp --header "Authorization: Bearer <token>"`.

## Why Deploy MemPalace on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you
don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying MemPalace on Railway, you are one step closer to supporting a complete full-stack application with
minimal burden. Host your servers, databases, AI agents, and more on Railway.
