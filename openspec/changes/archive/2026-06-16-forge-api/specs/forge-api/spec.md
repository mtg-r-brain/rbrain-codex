## ADDED Requirements

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

`rbrain-forge` SHALL expose exactly two **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`) and `POST /decks/parse` (defined here). Any additional public route — deck persistence (`POST /decks`, `GET /decks/{id}`), analysis, legality, or batch endpoints — requires a MODIFIED delta on `forge-api` before the route ships.

#### Scenario: New public route goes through OpenSpec

- **WHEN** a contributor adds `POST /decks` (persistence) or `GET /decks/{id}` to forge
- **THEN** the change SHALL include a MODIFIED requirement on this spec before the route ships; CI on forge alone is not enough to make it part of the public surface
