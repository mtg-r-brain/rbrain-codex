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

`rbrain-forge` SHALL expose exactly eight HTTP routes at v1: `GET /health` (defined by `repository-conventions`), the stateless in-cluster routes `POST /decks/parse` and `POST /decks/analyze`, and the user-scoped persistence routes `POST /decks`, `GET /decks`, `GET /decks/{id}`, `PUT /decks/{id}`, and `DELETE /decks/{id}` (defined here). Any additional route — deck sharing, legality, or batch endpoints — requires a MODIFIED delta on `forge-api` before the route ships.

The persistence routes (`/decks`, `/decks/{id}`) are reached only through the gateway's JWT-protected proxy (the `gateway → forge` edge); `POST /decks/parse` and `POST /decks/analyze` are stateless in-cluster routes serving the `cortex → forge` edge and are NOT gateway-proxied. forge serves all of them on its own port; authentication is the gateway's responsibility, ownership scoping (via `X-User-Id`) is forge's.

#### Scenario: New public route goes through OpenSpec

- **WHEN** a contributor adds a deck-sharing or legality endpoint to forge
- **THEN** the change SHALL include a MODIFIED requirement on this spec before the route ships; CI on forge alone is not enough to make it part of the surface

#### Scenario: Analyze is not publicly reachable

- **WHEN** an external client requests `POST /decks/analyze` through the gateway
- **THEN** the gateway SHALL NOT proxy it (the route is absent from `gateway-api`'s closed public set)

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

### Requirement: Deck analysis endpoint

`rbrain-forge` SHALL expose `POST /decks/analyze` on its declared service port. The request body SHALL be a JSON object with exactly two fields:

- `decklist` (string, required) — the raw decklist text; missing or blank SHALL be rejected with `422`.
- `card_facts` (array, required — MAY be empty) — per-card facts supplied by the caller, each `{name, mana_cost, type_line}` (strings; `mana_cost`/`type_line` MAY be empty). Missing (absent key) SHALL be rejected with `422`. forge SHALL NOT fetch card data itself — it has no lexicon edge; supplying facts is the caller's job (cortex, per `service-topology`).

forge SHALL parse the decklist (same parser as `POST /decks/parse`) and respond `200` with exactly these fields:

| Field | Type | Description |
|---|---|---|
| `mana_curve` | object | Histogram of mainboard non-land cards by converted mana cost: keys `"0"`…`"6"` and `"7+"`, integer counts weighted by quantity. |
| `average_cmc` | number | Quantity-weighted mean CMC of mainboard non-land cards; `0` when none. |
| `color_distribution` | object | Counts of mana symbols `W`,`U`,`B`,`R`,`G`,`C` across mainboard costs, weighted by quantity (cost-symbol approximation of color identity). |
| `type_breakdown` | object | Mainboard counts by primary card type (Creature, Instant, Sorcery, Artifact, Enchantment, Planeswalker, Battle, Land, Other), weighted by quantity. |
| `total_mainboard` | integer | Sum of mainboard quantities (parsed, resolved or not). |
| `unresolved` | array | Mainboard card names with no matching entry in `card_facts` (case-insensitive name match); analysis SHALL proceed over the resolved remainder. |

Name matching against `card_facts` SHALL be case-insensitive on the exact name. CMC SHALL be derived from the `mana_cost` string (`{2}{R}` → 3; `{X}` counts 0; hybrid/phyrexian symbols count 1 each).

#### Scenario: Curve and colors from supplied facts

- **WHEN** `POST /decks/analyze` receives a mono-red list (`4 Lightning Bolt`, `56 Mountain`) with facts giving Lightning Bolt `{R}`/Instant and Mountain ``/`Basic Land — Mountain`
- **THEN** `mana_curve` SHALL be `{"1": 4}` (lands excluded), `average_cmc` `1`, `color_distribution.R` `4`, `type_breakdown` `{"Instant": 4, "Land": 56}`, `total_mainboard` `60`, and `unresolved` empty

#### Scenario: Unknown cards degrade gracefully

- **WHEN** a mainboard name has no matching fact
- **THEN** the name SHALL appear in `unresolved`, its quantity SHALL still count in `total_mainboard`, and every other metric SHALL be computed from the resolved cards; the response stays `200`

#### Scenario: Missing card_facts is unprocessable

- **WHEN** the body carries a `decklist` but no `card_facts` key
- **THEN** the response SHALL be `422`

