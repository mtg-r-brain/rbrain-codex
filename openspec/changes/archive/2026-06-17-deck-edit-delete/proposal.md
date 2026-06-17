## Why

Users can save, list, and view decks but cannot change or remove them. This change completes deck CRUD with edit (`PUT /decks/{id}`) and delete (`DELETE /decks/{id}`), both user-scoped through the existing `gateway → forge` path.

## What Changes

- ADD `forge-api` requirement "Deck update and delete (user-scoped)":
  - `PUT /decks/{id}` — body `{ name?, decklist? }`, at least one present (else `422`). If `decklist` is present, forge re-parses it and replaces the deck's sections + `total_mainboard`; if `name` is present, it updates the name. Owner-scoped: `404` when the id is not owned by the caller. Responds `200` with the updated deck.
  - `DELETE /decks/{id}` — owner-scoped delete; `204 No Content` on success, `404` when not owned/absent.
  - Both require `X-User-Id` (401 if absent), like the other deck routes.
- MODIFY `forge-api` "No other public HTTP routes at v1": five → **seven** (add the two `/decks/{id}` methods).
- MODIFY `gateway-api` protected-routes requirement: add `PUT /decks/{id}` and `DELETE /decks/{id}` to the JWT-protected set proxied to forge (X-User-Id injected).

## Capabilities

### Modified Capabilities

- `forge-api`: deck update + delete; route count 5 → 7.
- `gateway-api`: deck edit/delete added to the protected route set.

## Impact

- **Contract only** here. Implementations: `rbrain-forge` (`DeckStore.update`/`delete`, handlers) and `rbrain-gateway` (PUT/DELETE on `/decks/*`), plus `rbrain-app` edit/delete UI.
- **No new sync edge** (reuses `gateway → forge`). **No schema change** (same `forge.decks` table).
- **Specs touched**: codex `forge-api`, `gateway-api`.
