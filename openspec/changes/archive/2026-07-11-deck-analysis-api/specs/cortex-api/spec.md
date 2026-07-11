# cortex-api — Delta

## ADDED Requirements

### Requirement: Deck analysis composition endpoint

`rbrain-cortex` SHALL expose `GET /decks/{deck_id}/analysis` on its declared service port, composing a stored deck's analysis deterministically — no LLM involvement: fetch the deck from forge (`GET /decks/{deck_id}`, `X-User-Id` forwarded), resolve each distinct mainboard card name to `{name, mana_cost, type_line}` facts via lexicon, and obtain the six analysis fields from forge's `POST /decks/analyze`.

The request SHALL carry the trusted `X-User-Id` header (injected by the gateway from the verified JWT `sub`, per `gateway-api`); a request without it SHALL be rejected `401` with a JSON `error` body. Cortex does NOT verify JWTs on this route; it trusts `X-User-Id`, as forge does.

The `200 OK` response SHALL be `Content-Type: application/json` with exactly two top-level fields:

| Field      | Type   | Description |
|------------|--------|-------------|
| `deck`     | object | `{id, name}` of the analyzed stored deck. |
| `analysis` | object | Exactly the six fields of forge's analyze contract: `mana_curve`, `average_cmc`, `color_distribution`, `type_breakdown`, `total_mainboard`, `unresolved`. |

When forge answers `404` for the deck (missing, or owned by another user — indistinguishable per `forge-api`), cortex SHALL answer `404 {"error": "deck not found"}`. A downstream failure (forge or lexicon unreachable or erroring) SHALL map to `502` with a JSON `error` body — never a bare `500`. Individual card names that lexicon cannot resolve SHALL NOT fail the request; they surface in `analysis.unresolved`, per forge's contract.

#### Scenario: Stored deck analysis round-trip

- **WHEN** `GET /decks/{deck_id}/analysis` arrives with `X-User-Id: U` for a deck owned by `U` whose mainboard is `4 Lightning Bolt / 56 Mountain`
- **THEN** the response SHALL be `200` with `deck.id = {deck_id}` and `analysis.mana_curve`, `analysis.average_cmc`, `analysis.color_distribution`, `analysis.type_breakdown`, `analysis.total_mainboard`, `analysis.unresolved` matching forge's analysis of that mainboard

#### Scenario: Foreign or missing deck is a 404

- **WHEN** `GET /decks/{deck_id}/analysis` arrives with `X-User-Id: V` for a deck owned by `U` (`U != V`) or a nonexistent id
- **THEN** the response SHALL be `404 {"error": "deck not found"}`, indistinguishable between the two cases

#### Scenario: Missing X-User-Id is rejected

- **WHEN** `GET /decks/{deck_id}/analysis` arrives without an `X-User-Id` header
- **THEN** the response SHALL be `401` with a JSON `error` body

## MODIFIED Requirements

### Requirement: No other public HTTP routes at v1

`rbrain-cortex` SHALL expose exactly three **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `POST /chat`, and `GET /decks/{deck_id}/analysis` (both defined here). Any additional public route — listing endpoints, batch endpoints, completions endpoints, websocket upgrades, conversation read endpoints — requires a MODIFIED delta on `cortex-api` before the route ships.

At v1, `rbrain-cortex` SHALL NOT expose any `/admin/*` route. Should an operator-only endpoint surface later (sync triggers, conversation purge, prompt overrides), an `/admin/*` carve-out comparable to `lexicon-api-admin-carveout` SHALL be introduced via its own OpenSpec change; only then are `/admin/*` routes permitted under this requirement.

#### Scenario: New public endpoint goes through OpenSpec

- **WHEN** a contributor adds `GET /conversations/{id}` or `POST /completions` to cortex
- **THEN** the change SHALL include a MODIFIED requirement on this spec; CI on cortex ALONE is not enough to make the new endpoint part of the public surface

#### Scenario: /health does not need a cortex-api requirement

- **WHEN** a contributor reads cortex-api/spec.md looking for `/health`
- **THEN** they SHALL find it referenced here as out-of-scope-for-this-capability and authoritative in `repository-conventions`; this spec SHALL NOT restate the `/health` contract

#### Scenario: Admin route requires a carve-out change first

- **WHEN** a contributor proposes `POST /admin/purge-conversations` against cortex
- **THEN** the change SHALL include both a new `/admin/*` carve-out requirement on `cortex-api` (mirroring `lexicon-api-admin-carveout`) AND the per-endpoint spec; merging the endpoint without the carve-out SHALL fail the closure clause
