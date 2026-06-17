## ADDED Requirements

### Requirement: Deck update and delete (user-scoped)

`rbrain-forge` SHALL expose owner-scoped edit and delete on a stored deck, identified by the trusted `X-User-Id` header (as for the other deck routes; a request without it SHALL be rejected `401`).

- `PUT /decks/{id}` — body `{ "name": <string?>, "decklist": <string?> }`. At least one field SHALL be present; a body with neither SHALL yield `422`. When `decklist` is present, forge SHALL re-parse it (per `forge-deck-parsing`) and replace the deck's `mainboard`/`sideboard`/`commander`/`maybeboard` and `total_mainboard`. When `name` is present, forge SHALL update the deck's name. On success forge SHALL respond `200` with the full updated deck. If the id is not owned by the caller, forge SHALL respond `404` (indistinguishable from absent).
- `DELETE /decks/{id}` — owner-scoped delete. On success forge SHALL respond `204 No Content` with no body. If the id is not owned by the caller (or absent), forge SHALL respond `404`.

#### Scenario: Owner edits a deck's name and list

- **WHEN** `PUT /decks/{id}` arrives with `X-User-Id: U` (the owner) and `{ "name": "new", "decklist": "1 Sol Ring" }`
- **THEN** forge SHALL respond `200` with the deck renamed to `new` and its mainboard replaced by the re-parsed list; a subsequent `GET /decks/{id}` SHALL reflect the update

#### Scenario: Edit with an empty body is rejected

- **WHEN** `PUT /decks/{id}` arrives with `{}` (neither `name` nor `decklist`)
- **THEN** forge SHALL respond `422` and SHALL NOT modify the deck

#### Scenario: Editing another user's deck is 404

- **WHEN** `PUT /decks/{id}` or `DELETE /decks/{id}` arrives with `X-User-Id: V` for a deck owned by `U` (`U != V`)
- **THEN** forge SHALL respond `404` and SHALL NOT modify or delete the deck

#### Scenario: Owner deletes a deck

- **WHEN** `DELETE /decks/{id}` arrives with `X-User-Id: U` for a deck owned by `U`
- **THEN** forge SHALL respond `204`; a subsequent `GET /decks/{id}` SHALL respond `404`

## MODIFIED Requirements

### Requirement: No other public HTTP routes at v1

`rbrain-forge` SHALL expose exactly seven HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `POST /decks/parse` (stateless parsing), and the user-scoped persistence routes `POST /decks`, `GET /decks`, `GET /decks/{id}`, `PUT /decks/{id}`, and `DELETE /decks/{id}` (defined here). Any additional route — deck sharing, analysis, legality, or batch endpoints — requires a MODIFIED delta on `forge-api` before the route ships.

The persistence routes (`/decks`, `/decks/{id}`) are reached only through the gateway's JWT-protected proxy (the `gateway → forge` edge); `POST /decks/parse` is the stateless parsing route. forge serves all of them on its own port; authentication is the gateway's responsibility, ownership scoping (via `X-User-Id`) is forge's.

#### Scenario: New public route goes through OpenSpec

- **WHEN** a contributor adds a deck-sharing or analysis endpoint to forge
- **THEN** the change SHALL include a MODIFIED requirement on this spec before the route ships; CI on forge alone is not enough to make it part of the surface
