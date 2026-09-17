# Security

## Threat model

The mempalace service is a **public** MCP endpoint. Its entire security boundary is the bearer token: anyone who
knows `MEMPALACE_MCP_HTTP_TOKEN` and the domain can read and write the shared memory over `POST /mcp`. The
template treats the token as the one secret that matters.

## What the template does

- **Mandatory bearer token.** `MEMPALACE_MCP_HTTP_TOKEN` is a generated 48-character secret. Upstream enforces it
  on every route except the credential-free `/healthz` liveness probe (which returns only `ok`). Requests without a
  valid `Authorization: Bearer …` header get `401`. The insecure "no token" override
  (`MEMPALACE_MCP_HTTP_ALLOW_INSECURE_NO_TOKEN`) is **never** set.
- **Token never on a command line.** `serve` passes the token to the server through the environment, so it never
  appears in the process list. The tests never print it; over HTTPS they read it from a mode-restricted file.
- **Qdrant is private.** It has no public domain and is reachable only by the mempalace service over Railway's
  encrypted private network. There is no way to reach the vector store from the internet.
- **No public sign-up, no UI.** There is no registration page or web UI to abuse — only the token-guarded API.
- **TLS at the edge.** Railway terminates HTTPS; the internal hop is plaintext HTTP inside the private network.
- **Pinned images.** Both images are pinned by digest (see `UPSTREAM.md`), so a deploy is reproducible.

## What you should do

- **Guard the token.** Anyone with it has full read/write to the memory. Share it only with your team's clients.
- **Rotate on exposure.** Change `MEMPALACE_MCP_HTTP_TOKEN` on the mempalace service; existing clients must update
  their header. (Rotating does not delete stored memories.)
- **Consider read-only clients.** MemPalace supports a `--read-only` server mode (recall without writes). To offer
  it, change the service's start command to add `--read-only`; the default here is read/write so a single team
  server is fully functional out of the box.
- **Back up the volumes.** Memories live on the qdrant and mempalace volumes; use Railway's volume backups.

## Reporting

For issues in MemPalace or Qdrant themselves, report upstream. For issues specific to this template's packaging,
open an issue on the template repository.
