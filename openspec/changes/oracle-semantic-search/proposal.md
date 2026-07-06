## Why

The rules agent can only retrieve a rule when the LLM already knows its number (`lookup_rule 702.21a`). Questions phrased in natural language — "why does my spell get countered unless I pay?" — have no retrieval path, which is the biggest gap between the platform today and its "MTG reasoning" vision. pgvector is active in the shared PostgreSQL, the embedding rail is decided (in-process ONNX in oracle, spike-validated, budgets rebalanced by `embedding-memory-rebalance`), and the corpus (3430 Comprehensive Rules) is loaded.

## What Changes

- MODIFY `oracle-api`:
  - ADD "Semantic rules search endpoint" — `GET /rules/search?q=<text>&limit=<k>`: `q` required non-empty (`400 {error, param}`), `limit` in `[1, 20]` default `5`; `200` body `{"results": [{number, text, score}], "limit": k, "query": q}` ranked by semantic similarity (`score` in `[0,1]`, descending); embedding computed in-process (model/dimensions are oracle sibling-spec detail).
  - MODIFY "No other public HTTP routes at v1": two → **three** public routes.
- MODIFY `gateway-api`:
  - MODIFY the JWT-protected proxies requirement: add `GET /rules/search` (flows through the existing `/rules/*` protected proxy).
  - MODIFY "No other public HTTP routes at v1": eighteen → **nineteen**.
  - MODIFY "CORS preflight discipline": add `GET /rules/search` to the enumerated preflight set (the uniform `/rules/*` deployment-level coverage already includes it).

## Capabilities

### Modified Capabilities

- `oracle-api`: semantic search route added; closure three.
- `gateway-api`: proxy + closure nineteen + CORS enumeration.

## Impact

- Implementation lands as sibling changes: `rbrain-oracle` (pgvector migration on the `oracle` schema, in-process embedder, sync-time indexation, search handler) and `rbrain-cortex` (`search_rules` agent tool over the existing cortex→oracle edge — no topology change). No new sync edge, no NATS change, no schema outside oracle's own.
