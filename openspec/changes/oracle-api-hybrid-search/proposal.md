# oracle-api-hybrid-search

## Why

`GET /rules/search` ranks by pure vector cosine similarity. Dense retrieval is strong on paraphrase ("creature that must be blocked" → menace-adjacent rules) but weak on exact-term anchoring: a verbatim rule phrase, a keyword name, or a rule number can lose to semantically-nearby-but-wrong neighbors. The current contract acknowledges this with a tuning note that pushes reformulation onto the calling agent (cortex's `search_rules`), and raw-query retrieval quality was flagged as a lesson during deck-analysis work (session 2026-07-05/06).

Hybrid retrieval — fusing the existing semantic channel with a lexical full-text channel — is the standard fix: the lexical channel anchors exact terms, the semantic channel keeps paraphrase recall, and rank fusion needs no score calibration between the two.

## What Changes

- MODIFY `oracle-api` › "Semantic rules search endpoint": retrieval is described as hybrid (semantic similarity fused with lexical full-text matching); `score` becomes a relevance score in `[0, 1]` (no longer defined as the raw cosine value); the reformulation note is relaxed — exact-term queries are now first-class, conversational reformulation remains the calling agent's option rather than a prerequisite. A scenario is added pinning exact-phrase anchoring.
- Route shape, parameters, response fields, error envelopes, in-process constraint, and empty-results-are-200 are all UNCHANGED — cortex and gateway need no code change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `oracle-api`: search requirement re-described as hybrid retrieval; one scenario added.

## Impact

- Contract wording only; the wire shape is byte-compatible with today's clients.
- Sibling implementation lands in `rbrain-oracle` (its `rules-semantic-search` capability gains the lexical channel + fusion — separate change in that repo).
- No gateway, cortex, or app change.
