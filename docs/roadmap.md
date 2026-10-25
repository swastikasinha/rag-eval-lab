# Roadmap — rag-eval-lab

An assistant that answers questions about RBI circulars with citations, plus an eval suite that scores it and blocks regressions in CI.

## Spec

**Corpus:** RBI circulars. They are public, dated and numbered, and some supersede others. Alternative if PDF parsing becomes a blocker: a large open-source project's docs plus GitHub issues. The corpus is downloaded locally by a script in the repo and never committed.

**Query types (each is an eval category):**

1. Factual lookup ("What documents are needed to open a minor's account?")
2. ID lookup (a specific circular number)
3. Multi-document questions
4. "Which rule is current?" (superseded circulars)
5. Unanswerable: the correct output is a refusal (~15% of the set)

**Metrics:**

- Retrieval: recall@k (k = 5, 10) and MRR against expected source documents.
- Generation: faithfulness, citation correctness (every cited chunk was actually retrieved), refusal accuracy on unanswerable questions. LLM-as-judge via Ragas or DeepEval.
- Ops: p95 latency, cost per query.
- Targets are set in `docs/design.md`.

**Architecture:** ingest PDFs → clean text + metadata (date, circular number, URL) → chunk → embed + keyword index → hybrid retrieve (dense + BM25, fused with RRF) → rerank (cross-encoder) → generate with mandatory citations → trace every step in Langfuse.

**Stack:** Python 3.12, uv, FastAPI, Postgres + pgvector (Qdrant as a comparison ADR), BM25, a multilingual-capable embedding model, a cross-encoder reranker, Langfuse + OpenTelemetry, pytest, ruff, Docker Compose, GitHub Actions.

## Conventions

- One branch and one PR per step; CI must be green before merge.
- Every design decision is an ADR in `docs/adr/`: "Proposed" first, "Accepted" only with measured numbers.
- Tune only on the `dev` eval split; `test` is for final numbers.
- LLM-drafted eval questions are each reviewed by hand before they enter the golden set.
- Never commit secrets, API keys, or the downloaded corpus (`data/` is gitignored).

## Steps

| Step | What | Done when |
| --- | --- | --- |
| 0 | Scaffold: CLAUDE.md, layout, uv, Makefile, docker-compose (pgvector), CI lint + tests | PR merged |
| 1 | **Design doc** `docs/design.md`: users, query types, targets, architecture, open decisions; ADR stubs (chunking, vector store, embedding model, reranker) | Doc merged, ADRs exist as "Proposed" |
| 2 | **Eval set first:** ingest 200–500 docs; ~150 hand-reviewed questions with expected sources + reference answers; dev/test split; `evals/run.py` | `make eval` prints a scorecard against a placeholder retriever |
| 3 | **Baseline:** parse → fixed-size chunks with overlap → embed → pgvector → generate with citations → FastAPI `/ask` with tracing | `results/baseline.json` committed |
| 4 | **Experiments**, one change at a time: + BM25 hybrid (RRF), + rerank, chunk size, contextual chunk headers; log every run below | Each ADR "Accepted" with numbers |
| 5 | **Testing + CI:** unit (parsers, chunkers, RRF, citation check), integration (compose + `/ask`), PR eval smoke test (30 questions, fail on threshold drop), nightly full dev set | A deliberately bad PR is blocked by CI |
| 6 | **Harden + ship:** caching, timeouts + fallback model, low-confidence refusal; hosted demo with rate limits; run the test split once; README with architecture, results, ADR links, "what I'd change at 10M docs" | README published, demo live |

## Results

| Experiment | Recall@10 | MRR | Faithfulness | p95 latency | Cost/query |
| --- | --- | --- | --- | --- | --- |
| Baseline (dense only) | | | | | |
| + BM25 hybrid (RRF) | | | | | |
| + cross-encoder rerank | | | | | |
| Chunk size 512 vs 1024 | | | | | |
| + contextual chunk headers | | | | | |

## Status

- Step 0: done.
- **Next:** step 1, the design doc.
