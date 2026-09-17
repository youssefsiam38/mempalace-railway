# Third-party notices

This template packages and runs the following third-party software. Each keeps its own licence; the template's own
files are MIT (see `LICENSE`).

## MemPalace

- Source: https://github.com/MemPalace/mempalace
- Licence: MIT — full text in `licenses/MEMPALACE-LICENSE`
- Copyright (c) 2026 MemPalace Contributors
- Used unmodified from the official image `ghcr.io/mempalace/mempalace` (pinned by digest in `UPSTREAM.md`). The
  wrapper image only sets the default command; it does not alter the application.

## Qdrant

- Source: https://github.com/qdrant/qdrant
- Licence: Apache-2.0 — https://github.com/qdrant/qdrant/blob/master/LICENSE
- Used unmodified from the official image `qdrant/qdrant` (pinned by digest in `UPSTREAM.md`).

## Embedding model

- Default model `minilm` (all-MiniLM-L6-v2) is downloaded at runtime by MemPalace from ChromaDB's model bucket into
  the `/data` cache on first use. It is not redistributed by this template.

---

"MemPalace" and "Qdrant" are the marks of their respective projects. This template is community-maintained and is
not affiliated with, or endorsed by, either project.
