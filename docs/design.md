# Design: rag-eval-lab

> Living document. Update it when the design changes; record the *why* of big
> choices as ADRs in `docs/adr/`. Items tagged **(JC-n)** are judgment calls,
> listed with their reasoning in [Judgment calls](#judgment-calls) at the end.

- **Status:** Draft
- **Last updated:** 2026-10-25

## Problem

RBI rules for banks and NBFCs are spread across thousands of circulars written over
decades. A new circular often amends or replaces an older one, so "what is the rule
today?" means reading a chain of documents and knowing which link is current. Keyword
search on the RBI website finds documents but does not answer the question, and a
generic chatbot answers confidently without saying where the answer came from.

**rag-eval-lab** answers questions over a fixed set of RBI circulars, cites the exact
circulars it used, and refuses when the corpus does not contain the answer. Answer
quality is measured on a golden eval set, and CI blocks changes that make it worse.

## Users

**Primary: a compliance officer at a bank, NBFC or fintech (JC-1).**

They need the current rule and the circular to quote in an internal memo or an audit
response. For them:

- a **wrong answer is worse than no answer**, so refusing is better than guessing;
- every claim needs a **citation** they can open and check (circular number, date, link);
- **"is this still in force?"** matters as much as the rule itself.

Example: *"What is the periodic KYC update interval for a high-risk customer?"* A
useful answer gives the interval, cites the Master Direction paragraph, and mentions
it if a later circular changed it.

## Goals and non-goals

**Goals**

- Answer the five query types below with inline citations to source circulars.
- Refuse unanswerable questions instead of guessing.
- Measure retrieval and generation quality on a hand-reviewed golden set, and run
  it in CI so a regression fails the PR.
- Trace every request end to end (retrieve, rerank, generate) so a bad answer can be
  explained.

**Non-goals (v1)**

- Legal or compliance advice. The system quotes and summarises circulars; it does not
  interpret them for a specific situation.
- Full RBI coverage. The corpus is a few topics only (see [Corpus](#corpus)).
- Live updates. The corpus is a fixed snapshot, refreshed by re-running ingest.
- Hindi queries. The embedding model is chosen to be multilingual so this stays
  possible later (JC-2).
- Multi-turn chat. Each question is answered on its own.

## Corpus

- **Scope (JC-3):** all circulars, Master Directions and Master Circulars from RBI on
  three topics: **KYC / AML**, **deposit accounts** (savings, term deposits, interest
  rates, minors' and dormant accounts) and **digital payments** (PPIs, UPI, card
  rules). Target size: 200–500 documents.
- **Why few topics, all years:** depth gives many supersession chains for the
  "which rule is current?" category, and a narrow scope makes unanswerable
  questions easy to define (anything outside the three topics, or a detail the
  circulars never state).
- **Metadata kept per document:** circular number (e.g. `RBI/2024-25/12`), reference
  number, title, issue date, issuing department, document type (circular / Master
  Direction / Master Circular), source URL, and supersession links where known.
- **Storage:** downloaded by a script into `data/` (gitignored, never committed).

## Query types

Each type is an eval category, so metrics are reported per category as well as
overall. The target mix for the ~150-question golden set (JC-4):

| # | Category | Example | Share |
| --- | --- | --- | --- |
| 1 | Factual lookup | "What documents are needed to open a minor's account?" | 40% |
| 2 | ID lookup | "What does circular RBI/YYYY-YY/NN say about PPI wallet limits?" (a real number from the corpus) | 10% |
| 3 | Multi-document | "How did the KYC update rules for low-risk customers change between 2016 and 2023?" | 15% |
| 4 | Which rule is current | "Is the 2017 limit on full-KYC PPIs still in force?" | 20% |
| 5 | Unanswerable | "What is RBI's rule on crypto staking?" (not in the corpus) | 15% |

## Evaluation

The golden set is built before any retrieval code exists (roadmap step 2), so the
system is never tuned to questions it was built around.

### Golden set

- One JSONL record per question: `id`, `category`, `question`, `expected_doc_ids`
  (empty for unanswerable), `reference_answer`, `split` (`dev` / `test`), `notes`.
- LLM-drafted questions are each reviewed and edited by hand before they enter the set.
- **Split:** about 100 `dev` / 50 `test`, stratified by category. All tuning uses `dev`.
  `test` is run once, at the end of step 6.

### Metrics

| Metric | What it measures | How |
| --- | --- | --- |
| **Recall@k** (k = 5, 10) | Did the right documents make it into the top k? | Per question: share of `expected_doc_ids` found in the top k results, averaged over answerable questions. Measured at **document level** (JC-5). |
| **MRR** | How high is the first right document? | Per question: 1 / rank of the first expected document (0 if none in the top k), averaged. |
| **Faithfulness** | Is every claim in the answer supported by the retrieved text? | LLM-as-judge (Ragas or DeepEval), with a different model from the generator (JC-6). |
| **Citation correctness** | Does every citation point to a chunk that was actually retrieved? | Deterministic check, no LLM. |
| **Refusal accuracy** | Does it refuse unanswerable questions and answer the rest? | Reported as two numbers: refusal rate on unanswerable, false-refusal rate on answerable. |
| **p95 latency, cost/query** | Is it usable and affordable? | From Langfuse traces over an eval run. |

A worked recall@k example: if the expected documents are {A, B} and the top 5 results
are [C, A, D, E, F], recall@5 is 1/2 = 0.5 and the reciprocal rank is 1/2 (A is at rank 2).

### Targets (provisional, JC-7)

Set before the baseline exists, so they will be revisited with step 3 numbers. A target
that turns out to be unreachable is lowered in a commit that says why.

| Metric | Target (dev split) |
| --- | --- |
| Recall@10 | ≥ 0.85 |
| MRR | ≥ 0.60 |
| Faithfulness | ≥ 0.90 |
| Citation correctness | 1.00 (any miss is a bug) |
| Refusal rate on unanswerable | ≥ 0.90 |
| False-refusal rate on answerable | ≤ 0.10 |
| p95 latency (end to end) | ≤ 4 s |
| Cost per query | ≤ $0.01 |

### In CI (roadmap step 5)

- **On every PR:** a 30-question smoke subset of `dev`. The PR fails if any metric
  drops more than a set margin below the last `main` run.
- **Nightly:** the full `dev` split, with results written to the Langfuse dataset.

## Architecture

```
            ingest (offline, make ingest)
 RBI site ──► download PDFs/HTML ──► parse + clean ──► chunk ──► embed ──► Postgres
                                       │                           │      (pgvector +
                                       └── metadata ───────────────┘       full-text)

            query (online, POST /ask)
 question ──► dense search  ─┐
          └─► BM25 search  ──┴─► RRF fusion ──► cross-encoder rerank ──► top n chunks
                                                                            │
 answer + citations ◄── citation check ◄── LLM (cite or refuse) ◄───────────┘

 Langfuse traces every online step; eval runs reuse the same pipeline.
```

The baseline (step 3) is dense search only. BM25 + RRF and reranking are added one
at a time in step 4, so each one's effect is measured on its own.

### Ingest (`src/ingest/`)

- Download each document once into `data/raw/`, keyed by circular number.
- Parse PDF/HTML to clean text, keeping headings and paragraph numbers (they are
  what a compliance officer cites).
- Extract supersession links from phrases like "stands superseded" / "in
  supersession of", and from the annexes of Master Directions that list the circulars
  they consolidate. Unresolved links are logged, not guessed (open decision D-4).
- Chunk the text (ADR 0002), embed the chunks (ADR 0004), and load documents and
  chunks into Postgres.

### Retrieve (`src/retrieve/`)

- **Dense:** cosine similarity on chunk embeddings in pgvector (ADR 0003).
- **Keyword:** BM25-style full-text search. This matters for ID lookups and exact
  terms like "PPI" that embeddings can blur.
- **Fusion:** Reciprocal Rank Fusion (RRF) merges the two ranked lists by rank, not by
  score, so the two scoring scales do not need to be comparable.
- **Rerank:** a cross-encoder rescores the fused top ~50 and keeps the top n (ADR 0005).
- **Current-rule boost (open decision D-4):** whether to down-rank chunks from
  superseded documents, or to keep them and let the generator explain the chain.

### Generate (`src/generate/`)

- The prompt contains the question and the top n chunks, each labelled with its
  circular number, date and chunk id.
- The model must cite a chunk id for every claim, or return a fixed refusal message
  when the chunks do not answer the question.
- A deterministic check then rejects any citation to a chunk that was not in the
  prompt.
- Model choice is open decision D-2.

### API (`src/api/`)

- `POST /ask` with `{question}` returns `{answer, citations: [{circular_no, title,
  date, url, chunk_id}], refused: bool, trace_id}`.
- `GET /health` for liveness.

## Data model (sketch, finalised in step 3)

- `documents`: `id`, `circular_no`, `ref_no`, `title`, `issued_on`, `department`,
  `doc_type`, `url`, `superseded_by` (nullable FK to `documents`).
- `chunks`: `id`, `document_id`, `ordinal`, `text`, `heading_path`,
  `embedding vector(d)`, `tsv tsvector`.
- Indexes: HNSW on `embedding`, GIN on `tsv`, B-tree on `circular_no`.

## Observability

- One Langfuse trace per `/ask` call, with spans for dense search, keyword search,
  fusion, rerank, the LLM call and the citation check. Each span records inputs,
  outputs, latency and (for LLM calls) tokens and cost.
- Each eval run is linked to a Langfuse dataset run, so a failing question opens
  straight to its trace.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| PDF parsing breaks on tables or scanned pages | Missing or garbled chunks, lower recall | Prefer HTML versions where RBI publishes them; spot-check parse output; fallback corpus noted in the roadmap. |
| Supersession links are incomplete | Wrong answers to "which rule is current?" | Measure category 4 separately; log unresolved links; hand-check the chains used in the golden set. |
| Small eval set (~150) | Metric differences of a few points can be noise | Report per-category counts; treat changes under ~5 points as inconclusive unless they repeat. |
| LLM judge is inconsistent or biased | Faithfulness scores drift between runs | Use a different model family from the generator; spot-check a sample of judgements by hand; pin judge model and prompt. |
| API cost of eval runs | Slow or expensive iteration | Cache retrieval results; smoke subset on PRs; full set nightly only. |

## Open decisions

Each becomes an ADR (status "Proposed" until measured numbers back it).

| ID | Decision | Options | ADR |
| --- | --- | --- | --- |
| D-1a | Chunking strategy | Fixed-size with overlap / structure-aware (by heading and paragraph) / contextual chunk headers | [0002](adr/0002-chunking-strategy.md) |
| D-1b | Vector store | pgvector / Qdrant | [0003](adr/0003-vector-store.md) |
| D-1c | Embedding model | Multilingual open model / hosted embedding API | [0004](adr/0004-embedding-model.md) |
| D-1d | Reranker | None / open cross-encoder / hosted rerank API | [0005](adr/0005-reranker.md) |
| D-2 | Generator model | Claude Haiku vs Sonnet (cost vs quality) | Later ADR, step 3 |
| D-3 | Eval framework and judge model | Ragas / DeepEval; judge model choice | Later ADR, step 2 |
| D-4 | Superseded documents | Filter / down-rank / keep and explain | Later ADR, step 4 |

## Judgment calls

Choices made in this draft that are worth challenging.

| ID | Call | Reasoning |
| --- | --- | --- |
| JC-1 | Primary user is a compliance officer | Makes precision, citations and refusals the priorities, which is what an eval-first project should stress. |
| JC-2 | No Hindi in v1, but pick a multilingual embedding model | Keeps scope small without closing the door. |
| JC-3 | Three topics (KYC/AML, deposits, digital payments), all years | Long supersession chains for category 4, and a clear boundary for unanswerable questions. |
| JC-4 | Category mix 40/10/15/20/15 | Weighted to the everyday case (factual) and the hard case this corpus is good at (current rule). |
| JC-5 | Recall measured at document level, not chunk level | Expected sources are labelled per document, which is cheaper to label by hand and matches what the user cites. Chunk-level recall can be added later. |
| JC-6 | Judge model differs from the generator | Reduces the risk of a model favouring its own outputs. |
| JC-7 | Targets set before the baseline | Forces a stated bar up front; revised with real numbers in step 3 and the change recorded. |
