## Why

The "Semantic rules search endpoint" acceptance scenario was authored before the implementation existed and turned out empirically false: the query "why is my spell countered unless I pay mana" does NOT surface `702.21a` in the top results (validated live 2026-07-06 — the 22M-parameter quantized embedder does not bridge that perspective flip across 3283 candidates). The endpoint itself works: keyword-anchored queries rank Ward first, and the agent loop reformulates user questions into exactly that shape (observed live: cortex issued `search_rules("ward keyword pay mana or countered")` → `702.21a` rank 1, quoted verbatim in the answer). A spec scenario must be a testable truth, not an aspiration.

## What Changes

- MODIFY `oracle-api` "Semantic rules search endpoint": the Ward acceptance scenario uses the empirically validated query shape, and the requirement body states the division of labor — the retriever is tuned for keyword-anchored queries; conversational reformulation is the calling agent's job (cortex `search_rules` tool description steers this).

## Capabilities

### Modified Capabilities

- `oracle-api`: scenario corrected to a verified retrieval.

## Impact

- Contract text only; no code.
