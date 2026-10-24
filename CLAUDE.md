# CLAUDE.md

## Project

rag-eval-lab is a personal learning project: an **eval-first** retrieval-augmented
generation (RAG) system over Reserve Bank of India (RBI) circulars.

- **Goal:** answer questions about RBI circulars, with citations back to the source circular.
- **Eval-first:** quality is measured by a golden eval set (`evals/golden/`) that runs in CI.
  - Retrieval: **recall@k**, **MRR**
  - Generation: **faithfulness** (answer is supported by the retrieved context)
- A change that touches retrieval or generation should come with an eval run, and a
  regression in these metrics is a bug.

## Stack

- **Python 3.12**, managed with **uv** (`uv sync`, `uv run ...`)
- **FastAPI** for the HTTP API (`src/api/`)
- **Postgres + pgvector** for chunk storage and vector search (`docker-compose.yml`)
- **Langfuse** for tracing LLM calls and eval runs
- **pytest** for tests, **ruff** for lint and formatting

## Layout

```
src/
  ingest/     # fetch + parse RBI circulars, chunk, embed, load into Postgres
  retrieve/   # query -> ranked chunks (vector / hybrid search)
  generate/   # ranked chunks -> cited answer
  api/        # FastAPI app
evals/
  golden/     # golden question/answer/source-circular set
tests/        # pytest suite
docs/
  design.md   # living design doc
  adr/        # architecture decision records (copy 0001-template.md)
data/         # raw + processed circulars (gitignored, never commit)
```

## Commands

```
make install   # uv sync
make lint      # ruff check + ruff format --check
make format    # ruff format + ruff check --fix
make test      # pytest
make eval      # run the golden eval set
make db-up     # start Postgres+pgvector via docker compose
make db-down   # stop it
```

## Conventions

- **Small PRs.** One concern per PR; each step of the roadmap is its own branch.
- **Tests with every change.** New behaviour ships with tests; bug fixes ship with a
  regression test.
- `make lint` and `make test` must pass before committing (CI enforces both on every PR).
- Record significant design choices (embedding model, chunking strategy, DB schema,
  metric definitions) as an ADR in `docs/adr/`.
- Never commit anything under `data/`, secrets, or `.env`. Use `.env.example` for
  documenting config.
- Prefer plain functions and explicit data types (dataclasses / pydantic models) over
  frameworks; keep each stage (`ingest`, `retrieve`, `generate`) independently testable.
