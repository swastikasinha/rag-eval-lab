# ADR 0004: Embedding model

- **Status:** Proposed
- **Date:** 2026-10-25

## Context

The embedding model decides what "similar" means for dense retrieval. RBI text is
formal, full of acronyms (KYC, PPI, NBFC) and defined terms. Hindi queries are a
non-goal for v1 but should stay possible, so a multilingual model is preferred
(design doc JC-2). The model must run within a personal budget.

## Decision

Pending. The baseline uses one multilingual open model run locally, chosen in step 3.

## Alternatives considered

- **Open multilingual model, run locally** (e.g. from the BGE-M3 or multilingual-E5
  families): no per-call cost, reproducible; slower on a laptop and needs the model
  download.
- **Hosted embedding API:** fast to start and often strong on English; per-call cost,
  data leaves the machine, and results can change if the provider updates the model.
- **Embedding dimension** (e.g. 384 vs 1024): smaller vectors are cheaper to store
  and search, at some cost in quality.

## Consequences

To be filled in. **Decided by:** recall@10 and MRR on the `dev` split with all else
fixed, plus embedding time for the full corpus and cost per query.
