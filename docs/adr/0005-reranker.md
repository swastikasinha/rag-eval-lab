# ADR 0005: Reranker

- **Status:** Proposed
- **Date:** 2026-10-25

## Context

First-stage retrieval (dense, BM25, fused with RRF) is fast but approximate. A
cross-encoder reads the question and each candidate chunk together and scores them
more accurately, but it is slower, so it only reranks the top ~50 candidates. The
question is whether the quality gain is worth the added latency and cost.

## Decision

Pending. The baseline has **no reranker**; one is added in step 4 and measured on its own.

## Alternatives considered

- **No reranker:** lowest latency and cost; relies on fusion to get the order right.
- **Open cross-encoder, run locally** (e.g. a multilingual BGE reranker): no per-call
  cost; adds CPU/GPU latency per query.
- **Hosted rerank API:** strong quality with no local compute; per-call cost and an
  external dependency in the request path.

## Consequences

To be filled in. **Decided by:** change in MRR and recall@5 on the `dev` split
(reranking mostly improves order, so MRR is the main signal), against the added p95
latency and cost per query.
