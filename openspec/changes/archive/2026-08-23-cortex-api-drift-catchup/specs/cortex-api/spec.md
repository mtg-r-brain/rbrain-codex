# cortex-api — Delta

## MODIFIED Requirements

### Requirement: Deck analysis composition endpoint

`rbrain-cortex` SHALL expose `GET /decks/{deck_id}/analysis` on its declared service port, composing a stored deck's analysis deterministically — no LLM involvement: fetch the deck from forge (`GET /decks/{deck_id}`, `X-User-Id` forwarded), resolve each distinct mainboard card name to `{name, mana_cost, type_line}` facts via lexicon, and obtain the six analysis fields from forge's `POST /decks/analyze`.

The request SHALL carry the trusted `X-User-Id` header (injected by the gateway from the verified JWT `sub`, per `gateway-api`); a request without it SHALL be rejected `401` with a JSON `error` body. Cortex does NOT verify JWTs on this route; it trusts `X-User-Id`, as forge does.

The `200 OK` response SHALL be `Content-Type: application/json` with exactly two top-level fields:

| Field      | Type   | Description |
|------------|--------|-------------|
| `deck`     | object | `{id, name, format, format_violations}` of the analyzed stored deck. |
| `analysis` | object | Exactly the six fields of forge's analyze contract: `mana_curve`, `average_cmc`, `color_distribution`, `type_breakdown`, `total_mainboard`, `unresolved`. |

The `deck` object SHALL carry exactly these four fields:

| Field | Type | Description |
|---|---|---|
| `id` | uuid | The stored deck's id. |
| `name` | string | The stored deck's name. |
| `format` | string \| null | The deck's chosen format, or `null` when none is set. |
| `format_violations` | array of `{name, status}` | Per `forge-api`'s `format_violations` field, passed through verbatim; `[]` when no format is set or none is violated. |

The `deck` object SHALL be built from individual `StoredDeck` attributes, never from a whole-payload dump, so its field set stays independent of what forge's stored-deck payload happens to carry.

When forge answers `404` for the deck (missing, or owned by another user — indistinguishable per `forge-api`), cortex SHALL answer `404 {"error": "deck not found"}`. A downstream failure (forge or lexicon unreachable or erroring) SHALL map to `502` with a JSON `error` body — never a bare `500`. Individual card names that lexicon cannot resolve SHALL NOT fail the request; they surface in `analysis.unresolved`, per forge's contract.

#### Scenario: Stored deck analysis round-trip

- **WHEN** `GET /decks/{deck_id}/analysis` arrives with `X-User-Id: U` for a deck owned by `U` whose mainboard is `4 Lightning Bolt / 56 Mountain`
- **THEN** the response SHALL be `200` with `deck.id = {deck_id}`, `deck.format` and `deck.format_violations` matching the stored deck's, and `analysis.mana_curve`, `analysis.average_cmc`, `analysis.color_distribution`, `analysis.type_breakdown`, `analysis.total_mainboard`, `analysis.unresolved` matching forge's analysis of that mainboard

#### Scenario: Foreign or missing deck is a 404

- **WHEN** `GET /decks/{deck_id}/analysis` arrives with `X-User-Id: V` for a deck owned by `U` (`U != V`) or a nonexistent id
- **THEN** the response SHALL be `404 {"error": "deck not found"}`, indistinguishable between the two cases

#### Scenario: Missing X-User-Id is rejected

- **WHEN** `GET /decks/{deck_id}/analysis` arrives without an `X-User-Id` header
- **THEN** the response SHALL be `401` with a JSON `error` body
