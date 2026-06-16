# forge-api Specification

## Purpose
TBD - created by archiving change forge-api. Update Purpose after archive.
## Requirements
### Requirement: Deck-list parse endpoint

`rbrain-forge` SHALL expose `POST /decks/parse` on its declared service port. The request body SHALL be a JSON object with exactly one field:

- `decklist` (string, required) — the raw decklist text to parse.

On a well-formed request, the endpoint SHALL respond `200 OK` with a JSON object containing:

- `mainboard` — array of deck entries from the main deck.
- `sideboard` — array of deck entries from the sideboard.
- `commander` — array of deck entries designated as commander(s).
- `maybeboard` — array of deck entries from the maybeboard.
- `errors` — array of `{ line, content, reason }` objects, one per non-blank line that could not be parsed (empty when every line parsed).
- `total_mainboard` — the sum of `quantity` across `mainboard` entries.

A deck entry is a JSON object `{ "quantity": <positive integer>, "name": <string> }`.

A request whose body is not a JSON object with a string `decklist` field SHALL respond `422 Unprocessable Entity` with `{ "error": "<message>" }`. A decklist that parses to zero entries (e.g. empty or all-unrecognised) is NOT an error: the endpoint SHALL still respond `200` with empty section arrays and any `errors`.

#### Scenario: A simple decklist parses into the mainboard

- **WHEN** `POST /decks/parse` receives `{ "decklist": "4 Lightning Bolt\n2 Counterspell" }`
- **THEN** the response SHALL be `200` with `mainboard` containing `{quantity:4, name:"Lightning Bolt"}` and `{quantity:2, name:"Counterspell"}`, `total_mainboard` `6`, and an empty `errors` array

#### Scenario: Sideboard and commander sections are separated

- **WHEN** the decklist contains a `Sideboard` header and/or a `Commander` header with entries beneath them
- **THEN** entries beneath each header SHALL appear in the matching `sideboard` / `commander` array, not in `mainboard`

#### Scenario: Unrecognised lines are reported, not fatal

- **WHEN** the decklist contains a line that is neither blank, a section header, nor a quantity+name entry
- **THEN** the response SHALL still be `200`; the offending line SHALL appear in `errors` with its `line` number and `content`; the parseable entries SHALL still be returned

#### Scenario: Missing decklist field is a 422

- **WHEN** the request body is `{}` or `decklist` is not a string
- **THEN** the response SHALL be `422` with an `error` message; no parsing SHALL be attempted

### Requirement: No other public HTTP routes at v1

`rbrain-forge` SHALL expose exactly five HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `POST /decks/parse` (stateless parsing), and the three user-scoped persistence routes `POST /decks`, `GET /decks`, and `GET /decks/{id}` (defined here). Any additional route — deck editing/delete, sharing, analysis, legality, or batch endpoints — requires a MODIFIED delta on `forge-api` before the route ships.

The persistence routes (`/decks`, `/decks/{id}`) are reached only through the gateway's JWT-protected proxy (the `gateway → forge` edge); `POST /decks/parse` is the stateless parsing route. forge serves all of them on its own port; authentication is the gateway's responsibility, ownership scoping (via `X-User-Id`) is forge's.

#### Scenario: New public route goes through OpenSpec

- **WHEN** a contributor adds `DELETE /decks/{id}` or a sharing endpoint to forge
- **THEN** the change SHALL include a MODIFIED requirement on this spec before the route ships; CI on forge alone is not enough to make it part of the surface

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

