# ADR 0002: Chunking strategy

- **Status:** Proposed
- **Date:** 2026-10-25

## Context

Retrieval works on chunks, not whole circulars. Chunks that are too large dilute the
embedding and waste prompt space; chunks that are too small lose the context a rule
needs (for example, a limit separated from the account type it applies to). RBI
circulars are structured: numbered paragraphs, headings, annexes and tables, and
compliance officers cite by paragraph.

## Decision

Pending. The baseline (step 3) uses **fixed-size chunks with overlap**, because it is
the simplest thing to measure against. Alternatives are tested one at a time in step 4.

## Alternatives considered

- **Fixed-size with overlap** (e.g. 512 or 1024 tokens, ~15% overlap): simple and
  predictable; ignores document structure, so a chunk can cut a paragraph in half.
- **Structure-aware** (split on headings and numbered paragraphs, merge small ones up
  to a size limit): chunks line up with what users cite; depends on clean parsing.
- **Contextual chunk headers** (prefix each chunk with circular title, date and heading
  path before embedding): helps short chunks that make no sense alone; adds tokens.

## Consequences

To be filled in with measured numbers. **Decided by:** recall@10 and MRR on the `dev`
split, plus faithfulness, for chunk sizes 512 vs 1024 and with or without contextual
headers (roadmap results table).
