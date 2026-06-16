## ADDED Requirements

### Requirement: Deck persistence endpoints (user-scoped)

`rbrain-forge` SHALL expose deck storage scoped to the requesting user, identified by a trusted `X-User-Id` header (injected by the gateway from the verified JWT `sub`). forge does NOT verify JWTs; it trusts `X-User-Id`. A deck-persistence request without an `X-User-Id` header SHALL be rejected `401` — forge SHALL NOT store or return an unattributed deck.

- `POST /decks` — body `{ "decklist": <string>, "name": <string?> }`. forge SHALL parse the decklist (per `forge-deck-parsing`), store the resulting deck owned by `X-User-Id`, and respond `201` with `{ id, name, mainboard, sideboard, commander, maybeboard, total_mainboard, created_at }`. The `decklist` field is required (missing → `422`).
- `GET /decks` — respond `200` with an array of the caller's deck summaries `{ id, name, total_mainboard, created_at }` (only decks owned by `X-User-Id`).
- `GET /decks/{id}` — respond `200` with the caller's full stored deck, or `404` when no deck with that id is owned by the caller (a deck owned by another user SHALL be indistinguishable from a missing one).

#### Scenario: Saving a deck attributes it to the caller

- **WHEN** `POST /decks` arrives with `X-User-Id: U` and `{ "decklist": "4 Lightning Bolt", "name": "burn" }`
- **THEN** forge SHALL store the parsed deck owned by `U` and respond `201` with a generated `id` and the parsed sections

#### Scenario: A deck is only readable by its owner

- **WHEN** `GET /decks/{id}` arrives with `X-User-Id: V` for a deck owned by `U` (`U != V`)
- **THEN** forge SHALL respond `404`, indistinguishable from a non-existent id

#### Scenario: Missing X-User-Id is rejected

- **WHEN** any `/decks` persistence route is called without an `X-User-Id` header
- **THEN** forge SHALL respond `401` and SHALL NOT store or return any deck

## MODIFIED Requirements

### Requirement: No other public HTTP routes at v1

`rbrain-forge` SHALL expose exactly five HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `POST /decks/parse` (stateless parsing), and the three user-scoped persistence routes `POST /decks`, `GET /decks`, and `GET /decks/{id}` (defined here). Any additional route — deck editing/delete, sharing, analysis, legality, or batch endpoints — requires a MODIFIED delta on `forge-api` before the route ships.

The persistence routes (`/decks`, `/decks/{id}`) are reached only through the gateway's JWT-protected proxy (the `gateway → forge` edge); `POST /decks/parse` is the stateless parsing route. forge serves all of them on its own port; authentication is the gateway's responsibility, ownership scoping (via `X-User-Id`) is forge's.

#### Scenario: New public route goes through OpenSpec

- **WHEN** a contributor adds `DELETE /decks/{id}` or a sharing endpoint to forge
- **THEN** the change SHALL include a MODIFIED requirement on this spec before the route ships; CI on forge alone is not enough to make it part of the surface
