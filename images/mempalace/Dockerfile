# syntax=docker/dockerfile:1
#
# MemPalace for the Railway template. This is the stock, official upstream image pinned by digest, with the
# default command set to run the remote HTTP MCP server (the "team server") instead of the stdio server. Nothing
# in the application is modified: the bearer token, the Qdrant backend and the data location are all supplied
# through environment variables by the template. Not affiliated with the MemPalace project.
#
# The upstream entrypoint (docker-entrypoint.sh) dispatches the first argument: "serve" is forwarded to
# `mempalace serve ...`, which starts `mempalace-mcp --transport http`. The bearer token rides in the
# environment (MEMPALACE_MCP_HTTP_TOKEN), never on the command line, so it never appears in the process list.
ARG MEMPALACE_IMAGE=ghcr.io/mempalace/mempalace:3.10.0@sha256:db5761316990215fc6f2db332e63db50f1e35b86fa8c5b3ae6bbf4ab1e61f902

FROM ${MEMPALACE_IMAGE}
ARG WRAPPER_VERSION=0.0.0-dev
ARG VCS_REF=unknown
ARG BUILD_DATE=1970-01-01T00:00:00Z

LABEL org.opencontainers.image.title="mempalace-railway" \
      org.opencontainers.image.description="MemPalace for the Railway template: the stock image configured to run the remote HTTP MCP server. Not affiliated with the MemPalace project." \
      org.opencontainers.image.source="https://github.com/youssefsiam38/mempalace-railway" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${WRAPPER_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"

# Run the remote HTTP MCP server on all interfaces. The port matches the template's PORT and public target port;
# the Qdrant backend and its URL are provided by the template's environment. Host pinning is disabled on a
# non-loopback bind (upstream), so the Railway domain in the Host header is accepted; the bearer token guards
# every route except the credential-free /healthz liveness probe.
CMD ["serve", "--host", "0.0.0.0", "--port", "8765", "--backend", "qdrant"]
