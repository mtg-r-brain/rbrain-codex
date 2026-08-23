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

The same gate SHALL apply to the **shape** of the existing eight routes, not only to their number. A change that adds, removes, or renames a field in any response payload, adds or removes an accepted request-body field, or adds or removes an accepted query parameter requires a MODIFIED delta on `forge-api` before it ships — even when the route set is untouched. A widening that leaves every existing field in place is still a contract change, because a consumer validating the payload against this document is entitled to have read a true description of it.

The persistence routes (`/decks`, `/decks/{id}`) are reached only through the gateway's JWT-protected proxy (the `gateway → forge` edge); `POST /decks/parse` and `POST /decks/analyze` are stateless in-cluster routes serving the `cortex → forge` edge and are NOT gateway-proxied. forge serves all of them on its own port; authentication is the gateway's responsibility, ownership scoping (via `X-User-Id`) is forge's.

#### Scenario: New public route goes through OpenSpec

- **WHEN** a contributor adds a deck-sharing or legality endpoint to forge
- **THEN** the change SHALL include a MODIFIED requirement on this spec before the route ships; CI on forge alone is not enough to make it part of the surface

#### Scenario: A response-shape widening goes through OpenSpec

- **WHEN** a contributor adds a field to a deck response payload, or a new accepted field to a `POST`/`PUT` body, without adding any route
- **THEN** the change SHALL include a MODIFIED requirement on this spec before it ships; documenting the field only in forge's own capability spec is not enough, because the cross-context consumers read this document

#### Scenario: Analyze is not publicly reachable

- **WHEN** an external client requests `POST /decks/analyze` through the gateway
- **THEN** the gateway SHALL NOT proxy it (the route is absent from `gateway-api`'s closed public set)

### Requirement: Deck persistence endpoints (user-scoped)

`rbrain-forge` SHALL expose deck storage scoped to the requesting user, identified by a trusted `X-User-Id` header (injected by the gateway from the verified JWT `sub`). forge does NOT verify JWTs; it trusts `X-User-Id`. A deck-persistence request without an `X-User-Id` header SHALL be rejected `401` — forge SHALL NOT store or return an unattributed deck.

The **full stored deck payload** returned by `POST /decks`, `GET /decks/{id}` and `PUT /decks/{id}` SHALL carry exactly these fields:

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `name` | string | `""` when the deck was stored without one. |
| `mainboard` | array of `{quantity, name}` | |
| `sideboard` | array of `{quantity, name}` | |
| `commander` | array of `{quantity, name}` | |
| `maybeboard` | array of `{quantity, name}` | |
| `total_mainboard` | integer | Sum of mainboard quantities. |
| `format` | string \| null | The deck's chosen format, one of the accepted identifiers listed below, or `null` when none is set. |
| `format_violations` | array of `{name, status}` | Per `forge-format-legality`; `[]` when no format is set or none is violated. |
| `status` | string | `"draft"` or `"saved"`. Per `forge-deck-persistence`. |
| `version` | integer \| null | Latest recorded version number, or `null` for a deck that never went through the draft path. |
| `errors` | array of `{line, content, reason}` | The lines of *this request's* `decklist` that the parser could not read, same shape as `POST /decks/parse` returns. Request-scoped, never stored — see below. |
| `created_at` | timestamp | |

`errors` describes the decklist text submitted in the request being answered, not a property of the stored deck, and forge SHALL NOT persist it. It SHALL be populated only where a parse occurred in that request:

- `POST /decks` — always populated (a create always parses a `decklist`), `[]` when every line was read.
- `PUT /decks/{id}` — populated when the request carried a `decklist`; `[]` when the request changed only `name`, `format` and/or `status`.
- `GET /decks/{id}`, with or without `?version=N` — always `[]`. A read parses nothing.

The key SHALL always be present with a stable type, empty rather than absent, so a consumer need not distinguish a missing key from an empty list.

**A consumer SHALL NOT read `errors: []` on a read as evidence that the deck's current content parses cleanly.** On a read the empty array means "this response parsed nothing", which is indistinguishable from "the last parse found nothing wrong". Determining whether a given decklist text parses cleanly requires submitting it — `POST /decks/parse` for a check without storing, or one of the write routes.

The **accepted `format` identifiers** are exactly: `standard`, `pioneer`, `modern`, `legacy`, `vintage`, `commander`, `pauper`, `duel`, `historic`, `alchemy`, `explorer`, `premodern`, `historicbrawl`, `standardbrawl`, `timeless`, `future`. The set is the platform format catalog — `openspec/specs/format-catalog/formats.yaml`, the single machine-readable source defined by the `format-catalog` capability, from which `rbrain-lexicon`'s published legality whitelist derives in turn — and codex CI checks this enumeration against it (`scripts/validate-formats.sh`); a change to the catalog is a change to this contract and SHALL come with a MODIFIED delta here, per the closure requirement above.

- `POST /decks` — body `{ "decklist": <string>, "name": <string?>, "format": <string?|null>, "status": <string?> }`. forge SHALL parse the decklist (per `forge-deck-parsing`), store the resulting deck owned by `X-User-Id`, and respond `201` with the full stored deck payload, `errors` carrying any lines the parser could not read. Unreadable lines SHALL NOT fail the request: the deck SHALL still be stored, with the entries that did parse, and the response SHALL still be `201` — consistent with `forge-deck-parsing`'s "parsing never fails the request" and with `POST /decks/analyze`'s `unresolved` list. The `decklist` field is required (missing → `422`). `format`, when present, SHALL be `null` or one of the accepted identifiers; any other value SHALL yield `422`. `status`, when present, SHALL be `"draft"` or `"saved"` and defaults to `"saved"`; any other value SHALL yield `422`.
- `GET /decks` — respond `200` with an array of the caller's deck summaries `{ id, name, total_mainboard, created_at }` (only decks owned by `X-User-Id`). Summaries SHALL NOT carry the full payload's additional fields, `errors` included — a summary describes a stored deck, never a submitted text. Per `forge-deck-persistence`, decks whose `status` is `"draft"` are excluded from this listing.
- `GET /decks/{id}` — respond `200` with the caller's full stored deck payload, or `404` when no deck with that id is owned by the caller (a deck owned by another user SHALL be indistinguishable from a missing one). An optional `?version=N` query parameter SHALL return that historical snapshot's sections in place of current state, with `version` set to `N`; a non-integer or non-positive `N` SHALL yield `422`, and an `N` with no such recorded version SHALL yield `404` (indistinguishable from a missing deck).

#### Scenario: Saving a deck attributes it to the caller

- **WHEN** `POST /decks` arrives with `X-User-Id: U` and `{ "decklist": "4 Lightning Bolt", "name": "burn" }`
- **THEN** forge SHALL store the parsed deck owned by `U` and respond `201` with a generated `id`, the parsed sections, and the remaining fields of the full stored deck payload — `format: null`, `format_violations: []`, `status: "saved"`, `version: null`, `errors: []`

#### Scenario: An unreadable line is reported and the deck still saves

- **WHEN** `POST /decks` arrives with `X-User-Id: U` and `{ "decklist": "4 Lightning Bolt\nthis is not a card line\n2 Counterspell" }`
- **THEN** forge SHALL respond `201`; the mainboard SHALL carry the two readable entries; `errors` SHALL carry one entry naming line `2`, its `content`, and a `reason`

#### Scenario: Replacing a decklist reports that request's unreadable lines

- **WHEN** `PUT /decks/{id}` arrives from the owner with a `decklist` whose third line is unreadable
- **THEN** forge SHALL respond `200` with the deck's sections replaced by the readable entries and `errors` carrying that line; the errors SHALL describe the text submitted in *this* request, not any earlier one

#### Scenario: A metadata-only update reports no errors

- **WHEN** `PUT /decks/{id}` arrives from the owner with `{ "name": "new" }` and no `decklist`, for a deck whose last decklist submission had unreadable lines
- **THEN** forge SHALL respond `200` with `errors: []` — no parse occurred in this request, and the earlier request's errors were never stored

#### Scenario: A read never reports errors

- **WHEN** `GET /decks/{id}` arrives from the owner, with or without `?version=N`, for a deck whose last decklist submission had unreadable lines
- **THEN** forge SHALL respond `200` with `errors: []`; the empty array SHALL NOT be read as evidence that the deck's content parses cleanly

#### Scenario: A deck is only readable by its owner

- **WHEN** `GET /decks/{id}` arrives with `X-User-Id: V` for a deck owned by `U` (`U != V`)
- **THEN** forge SHALL respond `404`, indistinguishable from a non-existent id

#### Scenario: Missing X-User-Id is rejected

- **WHEN** any `/decks` persistence route is called without an `X-User-Id` header
- **THEN** forge SHALL respond `401` and SHALL NOT store or return any deck

#### Scenario: An unknown format is rejected

- **WHEN** `POST /decks` arrives with `{ "decklist": "4 Lightning Bolt", "format": "gladiator" }` and `gladiator` is not among the accepted identifiers
- **THEN** forge SHALL respond `422` and SHALL NOT store the deck

#### Scenario: A historical version is fetched back

- **WHEN** `GET /decks/{id}?version=2` arrives from the owner of a draft deck that has recorded at least two versions
- **THEN** forge SHALL respond `200` with version 2's sections and `version: 2`

#### Scenario: An out-of-range version is not found

- **WHEN** `GET /decks/{id}?version=99` arrives from the owner of a deck with fewer than 99 recorded versions
- **THEN** forge SHALL respond `404`, indistinguishable from a missing deck

### Requirement: Deck update and delete (user-scoped)

`rbrain-forge` SHALL expose owner-scoped edit and delete on a stored deck, identified by the trusted `X-User-Id` header (as for the other deck routes; a request without it SHALL be rejected `401`).

- `PUT /decks/{id}` — body `{ "name": <string?>, "decklist": <string?>, "format": <string?|null>, "status": <string?> }`. At least one of the four fields SHALL be present; a body with none SHALL yield `422`. When `decklist` is present, forge SHALL re-parse it (per `forge-deck-parsing`) and replace the deck's `mainboard`/`sideboard`/`commander`/`maybeboard` and `total_mainboard`, reporting any unreadable lines in the response's `errors` without failing the request. When `name` is present, forge SHALL update the deck's name. When `format` is present, forge SHALL set it (or clear it when `null`) and recompute `format_violations`; a value outside the accepted identifiers SHALL yield `422`. When `status` is present, forge SHALL apply the draft/saved lifecycle transition defined by `forge-deck-persistence`, which admits `"draft"` → `"saved"` only and yields `422` for an unsupported transition or a promotion that would leave the deck unnamed. On success forge SHALL respond `200` with the full stored deck payload defined by the persistence requirement above. If the id is not owned by the caller, forge SHALL respond `404` (indistinguishable from absent).
- `DELETE /decks/{id}` — owner-scoped delete. On success forge SHALL respond `204 No Content` with no body. If the id is not owned by the caller (or absent), forge SHALL respond `404`.

#### Scenario: Owner edits a deck's name and list

- **WHEN** `PUT /decks/{id}` arrives with `X-User-Id: U` (the owner) and `{ "name": "new", "decklist": "1 Sol Ring" }`
- **THEN** forge SHALL respond `200` with the deck renamed to `new` and its mainboard replaced by the re-parsed list; a subsequent `GET /decks/{id}` SHALL reflect the update

#### Scenario: Edit with an empty body is rejected

- **WHEN** `PUT /decks/{id}` arrives with `{}` (none of `name`, `decklist`, `format`, `status`)
- **THEN** forge SHALL respond `422` and SHALL NOT modify the deck

#### Scenario: Editing another user's deck is 404

- **WHEN** `PUT /decks/{id}` or `DELETE /decks/{id}` arrives with `X-User-Id: V` for a deck owned by `U` (`U != V`)
- **THEN** forge SHALL respond `404` and SHALL NOT modify or delete the deck

#### Scenario: A format-only edit recomputes violations

- **WHEN** `PUT /decks/{id}` arrives from the owner with `{ "format": "modern" }` and no `decklist`
- **THEN** forge SHALL respond `200` with `format: "modern"` and `format_violations` recomputed against the deck's existing sections

#### Scenario: Un-saving a deck is rejected

- **WHEN** `PUT /decks/{id}` arrives from the owner with `{ "status": "draft" }` for a deck whose current `status` is `"saved"`
- **THEN** forge SHALL respond `422` and SHALL NOT modify the deck

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

### Requirement: Additive response fields and consumer tolerance

An additive change to a forge response payload SHALL be documented in this contract before it ships, **and** a consumer of a forge response SHALL ignore fields it does not recognise rather than rejecting the payload. Both obligations hold at once: neither one alone is sufficient, and each covers the other's failure mode.

The producer obligation is the delta gate stated by the closure requirement above. The consumer obligation constrains how `rbrain-cortex`, `rbrain-app`, and any future reader of a forge payload build their models of it: a deserialiser configured to reject unknown fields turns a backwards-compatible widening on forge's side into a runtime failure on the consumer's side, on a route that was working. Consumers SHALL NOT be configured that way against a forge payload.

A consumer that wants eager detection of contract drift SHALL obtain it from a contract test comparing a recorded forge payload against its expected field set, where a mismatch fails that consumer's CI — not from strict rejection in the model that serves production traffic.

This requirement is stated for forge's consumers. Extending it to the platform's other `<context>-api` contracts is deliberately not in its scope.

#### Scenario: forge grows a response field

- **WHEN** forge adds a field to the full stored deck payload, documented by a MODIFIED delta on this spec
- **THEN** a consumer deserialising that payload SHALL continue to operate on the fields it knows, ignoring the new one, without a lockstep release

#### Scenario: A consumer rejects an unknown field

- **WHEN** a consumer's forge-payload model is configured to reject unrecognised fields
- **THEN** that configuration SHALL be treated as a defect in the consumer, remedied by ignoring unknown fields and moving drift detection into a contract test

#### Scenario: An undocumented widening is still a contract violation

- **WHEN** forge ships a new response field without a MODIFIED delta on this spec, and every consumer tolerates it
- **THEN** the absence of a runtime failure SHALL NOT make the omission acceptable; the delta is still owed, and the contract is stale until it lands

