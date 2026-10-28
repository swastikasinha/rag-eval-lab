# ADR 0003: Vector store

- **Status:** Proposed
- **Date:** 2026-10-25

## Context

We need to store a few hundred documents' worth of chunk embeddings (tens of thousands
of vectors at most), run nearest-neighbour search, and also run keyword (BM25-style)
search for hybrid retrieval. Metadata filters (date, document type, superseded or not)
are needed for "which rule is current?" questions.

## Decision

Pending. The baseline uses **Postgres + pgvector**, already in `docker-compose.yml`.

## Alternatives considered

- **pgvector:** vectors, full-text search and metadata live in one database with SQL
  joins and transactions; one service to run. HNSW index support. Full-text ranking is
  not true BM25 out of the box.
- **Qdrant:** purpose-built vector database with payload filtering and built-in
  hybrid (sparse + dense) search; one more service to operate, and metadata joins
  move into application code.

## Consequences

To be filled in. **Decided by:** recall@10 and p95 retrieval latency on the same
chunks and embeddings in both stores, plus operational cost (services to run, code to
maintain). At this corpus size both are expected to be fast enough, so simplicity is
likely to decide it.
