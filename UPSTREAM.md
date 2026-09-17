# Upstream and pinned versions

This template packages **MemPalace** (the "remote team server": MCP over HTTP) with a **Qdrant** vector store.
Both are run from their official images, pinned by digest.

## MemPalace

- Project: https://github.com/MemPalace/mempalace
- Licence: MIT (`licenses/MEMPALACE-LICENSE`)
- Official image: `ghcr.io/mempalace/mempalace`
- Pinned: `ghcr.io/mempalace/mempalace:3.10.0`
  - digest `sha256:db5761316990215fc6f2db332e63db50f1e35b86fa8c5b3ae6bbf4ab1e61f902` (multi-arch index; Railway builds linux/amd64: `sha256:41045bb7386eb24151e87e094661baa2e757e870f48b61bfe93a5c56e346fafe`)
- The wrapper image (`images/mempalace/Dockerfile`) is `FROM` that digest and only sets the default command to run
  the remote HTTP MCP server (`serve --host 0.0.0.0 --port 8765 --backend qdrant`). The application is unmodified.

## Qdrant

- Project: https://github.com/qdrant/qdrant
- Licence: Apache-2.0
- Official image: `qdrant/qdrant`
- Pinned: `qdrant/qdrant:v1.19.1`
  - digest `sha256:12364fe851b9f17356fc88189fc06d1b521262e04659ec7345975b00c9246a10` (multi-arch index; linux/amd64: `sha256:0699e7733a6fa7fa7f6b95dcbed84ebb04584110da525cdfdef9f305c4f57738`)
- Run as-is with `QDRANT__SERVICE__HOST=::` so it is reachable over Railway's IPv6 private network (dual-stack on
  Linux). Not exposed publicly.

## Refreshing a digest

```bash
docker buildx imagetools inspect ghcr.io/mempalace/mempalace:<tag> --format '{{json .Manifest}}' | jq -r .digest
docker buildx imagetools inspect qdrant/qdrant:<tag>            --format '{{json .Manifest}}' | jq -r .digest
```

Update the pins here, in `images/mempalace/Dockerfile` (`ARG MEMPALACE_IMAGE`), in `compose.yaml` (qdrant image),
and in `_audit/spec_mempalace.py`, then bump the wrapper tag and re-run the tests. See `MAINTENANCE.md`.
