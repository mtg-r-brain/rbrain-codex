## 1. Contract (rbrain-codex)

- [ ] 1.1 oracle-api: ADD semantic search endpoint; MODIFY closure two → three (+ route-ordering scenario).
- [ ] 1.2 gateway-api: MODIFY protected proxies (+ /rules/search scenario), closure eighteen → nineteen, CORS enumeration.
- [ ] 1.3 `openspec validate oracle-semantic-search --strict` passes.

## 2. Archive

- [ ] 2.1 Push planning commit; archive; push archive commit.

## 3. Implementations (sibling changes — next session)

- [ ] 3.1 `rbrain-oracle` `rules-semantic-search`: migration `ALTER TABLE oracle.rules ADD COLUMN embedding vector(384)` + HNSW index; in-process embedder (fastembed-rs, quantized MiniLM-L6-v2 — model artifacts BAKED into the image at build, no runtime download in distroless); embed-at-sync (batch 8, per spike) + idempotent backfill via sync re-run; `GET /rules/search` handler (q/limit validation, cosine similarity via pgvector `<=>`, score mapping to [0,1]); tests incl. the Ward retrieval scenario.
- [ ] 3.2 `rbrain-gateway`: /rules/search flows through the existing `/rules/*rest` protected proxy — verify with a test; no route addition expected.
- [ ] 3.3 `rbrain-cortex` `search-rules-tool`: `search_rules(query, limit?)` agent tool over cortex→oracle; SYSTEM_PROMPT extended (prefer search_rules for natural-language rules questions, lookup_rule for known numbers).
- [ ] 3.4 Runtime validation on the deploy stack at the NEW contractual limits (oracle 160m, cortex 176m): sync-time indexation peak recorded; Ward scenario through the gateway; chat-driven search_rules; peak RSS in the archive commit message.
