# lexicon-api Specification

## Purpose
TBD - created by archiving change lexicon-api. Update Purpose after archive.
## Requirements
### Requirement: rbrain-lexicon exposes GET /cards/{scryfall_id}

`rbrain-lexicon` SHALL expose an HTTP endpoint at the path `GET /cards/{scryfall_id}` on its declared service port. The `{scryfall_id}` segment is a path parameter passed verbatim from the URL to the handler — no normalization, no decoding beyond standard URL decoding, no length cap at v1.

Callers reachable by this endpoint follow the synchronous call graph in `service-topology/sync-graph.yaml`. At v1, the only declared in-cluster caller is `rbrain-cortex` via the `cortex → lexicon` edge.

#### Scenario: cortex calls /cards/{id}

- **WHEN** `rbrain-cortex` issues `GET /cards/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd` against `rbrain-lexicon`
- **THEN** the request SHALL reach the handler and produce either the 200 response defined below or the 404 response defined below; the gateway is NOT in the path (lexicon is internal-only per `service-topology`)

#### Scenario: path parameter is opaque

- **WHEN** `{scryfall_id}` is any non-empty string (not necessarily a valid UUID)
- **THEN** the endpoint SHALL NOT reject the request at the routing layer; the lookup proceeds and falls through to the 404 response when the id is unknown

### Requirement: 200 response carries the Card payload

When the requested `scryfall_id` matches a card in the lexicon store, the response SHALL be:

- Status: `200 OK`
- `Content-Type: application/json`
- Body: a JSON object with exactly the six fields below, in any key order:

| Field          | Type   | Description                                                  |
|----------------|--------|--------------------------------------------------------------|
| `scryfall_id`  | string | Scryfall's id for the printing                               |
| `oracle_id`    | string | Scryfall's stable id for the oracle text (one per name)      |
| `name`         | string | Card name                                                    |
| `mana_cost`    | string | Mana cost in Scryfall notation, e.g. `"{2}{R}{R}"` or `"{0}"`|
| `type_line`    | string | Type line, e.g. `"Creature — Goblin"` or `"Artifact"`        |
| `oracle_text`  | string | Oracle text, may be empty for vanilla cards                  |

All fields are `string` at v1. Numeric or enum-typed fields are NOT introduced here; their addition (e.g. `cmc`, `colors`) requires a MODIFIED delta on this requirement.

Concrete example for `scryfall_id = bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd`:

```json
{
  "scryfall_id": "bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd",
  "oracle_id": "56719f6a-1a6c-4c0a-8d21-18f7d7350b68",
  "name": "Black Lotus",
  "mana_cost": "{0}",
  "type_line": "Artifact",
  "oracle_text": "{T}, Sacrifice Black Lotus: Add three mana of any one color."
}
```

#### Scenario: Black Lotus 200 payload matches the example

- **WHEN** `GET /cards/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd` is issued at v1
- **THEN** the body SHALL deserialize to a JSON object structurally equivalent to the example above, with the same six fields and the same values

#### Scenario: Extra fields are forbidden

- **WHEN** the 200 response body is parsed
- **THEN** it SHALL NOT carry any field outside the six listed above; adding a seventh field requires an OpenSpec change against this requirement

#### Scenario: All fields are strings

- **WHEN** the consumer parses the 200 body
- **THEN** every value SHALL be a JSON string; numbers, booleans, arrays, and nested objects are forbidden in v1

### Requirement: 404 response carries a structured error payload

When the requested `scryfall_id` does NOT match any card in the lexicon store, the response SHALL be:

- Status: `404 Not Found`
- `Content-Type: application/json`
- Body: a JSON object with exactly the two fields below:

| Field          | Type   | Description                                          |
|----------------|--------|------------------------------------------------------|
| `error`        | string | Constant value `"card not found"`                    |
| `scryfall_id`  | string | The raw path parameter received by the handler       |

Concrete example for `scryfall_id = 00000000-0000-0000-0000-000000000000`:

```json
{
  "error": "card not found",
  "scryfall_id": "00000000-0000-0000-0000-000000000000"
}
```

#### Scenario: Unknown id produces the structured 404

- **WHEN** `GET /cards/00000000-0000-0000-0000-000000000000` is issued
- **THEN** the response SHALL be HTTP 404 with the example body above (the `scryfall_id` value echoes the request)

#### Scenario: Empty body 404 is forbidden

- **WHEN** the lookup misses
- **THEN** the response body SHALL NOT be empty; the two-field structured payload above SHALL be returned with `Content-Type: application/json`

#### Scenario: error message is the fixed string

- **WHEN** any 404 response is parsed
- **THEN** `error` SHALL be exactly the literal `"card not found"`; case, spacing, and wording are part of the contract

### Requirement: No other HTTP routes at v1

`rbrain-lexicon` SHALL expose exactly two HTTP routes at v1: `GET /health` (defined by `repository-conventions`) and `GET /cards/{scryfall_id}` (defined here). Any additional route — `POST`, `PUT`, `DELETE`, list endpoints, search endpoints, batch endpoints — requires a MODIFIED delta on `lexicon-api` before the route ships.

#### Scenario: New endpoint goes through OpenSpec

- **WHEN** a contributor adds `GET /cards/by-name/{name}` to lexicon
- **THEN** the change SHALL include a MODIFIED requirement on this spec; CI on lexicon ALONE is not enough to make the new endpoint part of the public surface

