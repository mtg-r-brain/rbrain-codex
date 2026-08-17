# forge-api — Delta

## MODIFIED Requirements

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
| `format` | string \| null | The deck's chosen format, one of the sixteen identifiers listed below, or `null` when none is set. |
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

The **accepted `format` identifiers** are exactly these sixteen: `standard`, `pioneer`, `modern`, `legacy`, `vintage`, `commander`, `pauper`, `duel`, `historic`, `alchemy`, `explorer`, `premodern`, `historicbrawl`, `standardbrawl`, `timeless`, `future`. The set derives from the legality whitelist `rbrain-lexicon` publishes on `rbrain.lexicon.card-legality-updated`; a change to it is a change to this contract and SHALL come with a MODIFIED delta here, per the closure requirement above.

- `POST /decks` — body `{ "decklist": <string>, "name": <string?>, "format": <string?|null>, "status": <string?> }`. forge SHALL parse the decklist (per `forge-deck-parsing`), store the resulting deck owned by `X-User-Id`, and respond `201` with the full stored deck payload, `errors` carrying any lines the parser could not read. Unreadable lines SHALL NOT fail the request: the deck SHALL still be stored, with the entries that did parse, and the response SHALL still be `201` — consistent with `forge-deck-parsing`'s "parsing never fails the request" and with `POST /decks/analyze`'s `unresolved` list. The `decklist` field is required (missing → `422`). `format`, when present, SHALL be `null` or one of the sixteen accepted identifiers; any other value SHALL yield `422`. `status`, when present, SHALL be `"draft"` or `"saved"` and defaults to `"saved"`; any other value SHALL yield `422`.
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

- **WHEN** `POST /decks` arrives with `{ "decklist": "4 Lightning Bolt", "format": "gladiator" }` and `gladiator` is not among the sixteen accepted identifiers
- **THEN** forge SHALL respond `422` and SHALL NOT store the deck

#### Scenario: A historical version is fetched back

- **WHEN** `GET /decks/{id}?version=2` arrives from the owner of a draft deck that has recorded at least two versions
- **THEN** forge SHALL respond `200` with version 2's sections and `version: 2`

#### Scenario: An out-of-range version is not found

- **WHEN** `GET /decks/{id}?version=99` arrives from the owner of a deck with fewer than 99 recorded versions
- **THEN** forge SHALL respond `404`, indistinguishable from a missing deck

### Requirement: Deck update and delete (user-scoped)

`rbrain-forge` SHALL expose owner-scoped edit and delete on a stored deck, identified by the trusted `X-User-Id` header (as for the other deck routes; a request without it SHALL be rejected `401`).

- `PUT /decks/{id}` — body `{ "name": <string?>, "decklist": <string?>, "format": <string?|null>, "status": <string?> }`. At least one of the four fields SHALL be present; a body with none SHALL yield `422`. When `decklist` is present, forge SHALL re-parse it (per `forge-deck-parsing`) and replace the deck's `mainboard`/`sideboard`/`commander`/`maybeboard` and `total_mainboard`, reporting any unreadable lines in the response's `errors` without failing the request. When `name` is present, forge SHALL update the deck's name. When `format` is present, forge SHALL set it (or clear it when `null`) and recompute `format_violations`; a value outside the sixteen accepted identifiers SHALL yield `422`. When `status` is present, forge SHALL apply the draft/saved lifecycle transition defined by `forge-deck-persistence`, which admits `"draft"` → `"saved"` only and yields `422` for an unsupported transition or a promotion that would leave the deck unnamed. On success forge SHALL respond `200` with the full stored deck payload defined by the persistence requirement above. If the id is not owned by the caller, forge SHALL respond `404` (indistinguishable from absent).
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
