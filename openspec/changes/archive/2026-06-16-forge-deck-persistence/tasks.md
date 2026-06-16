## 1. Contract (rbrain-codex)

- [ ] 1.1 MODIFY `service-topology` "Authoritative synchronous call graph" — add `gateway → forge`; update `sync-graph.yaml` (DAG preserved).
- [ ] 1.2 MODIFY `gateway-api` protected-routes requirement — add `POST /decks`, `GET /decks`, `GET /decks/{id}`.
- [ ] 1.3 forge-api: ADD "Deck persistence endpoints (user-scoped)"; MODIFY route enumeration 2 → 5.
- [ ] 1.4 `openspec validate forge-deck-persistence --strict` passes.

## 2. Archive

- [ ] 2.1 Push planning commit.
- [ ] 2.2 Archive + `git add -A openspec/`; promote canonical service-topology / gateway-api / forge-api.
- [ ] 2.3 Push the archive commit.

## 3. Implementations (sibling changes)

- [ ] 3.1 `rbrain-forge` `forge-deck-persistence`: docker-compose (Postgres :5437, forge schema), sqlx + migration `0001_create_decks.sql`, `DeckStore` (save/get/list by user_id), `X-User-Id` extraction (401 if absent), `POST /decks` + `GET /decks` + `GET /decks/{id}` handlers, tests.
- [ ] 3.2 `rbrain-gateway` `gateway-deck-routes`: `FORGE_URL` config, three protected routes proxying to forge (StripAuthInjectUserId), spec MODIFY, test.
