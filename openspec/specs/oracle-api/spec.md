# oracle-api Specification

## Purpose
TBD - created by archiving change oracle-api. Update Purpose after archive.
## Requirements
### Requirement: rbrain-oracle exposes GET /rules/{number}

`rbrain-oracle` SHALL expose an HTTP endpoint at the path `GET /rules/{number}` on its declared service port. The `{number}` segment is a path parameter passed verbatim from the URL to the handler — no normalization, no decoding beyond standard URL decoding, no length cap at v1.

Callers reachable by this endpoint follow the synchronous call graph in `service-topology/sync-graph.yaml`. At v1, the only declared in-cluster caller is `rbrain-cortex` via the `cortex → oracle` edge.

#### Scenario: cortex calls /rules/{number}

- **WHEN** `rbrain-cortex` issues `GET /rules/100.1` against `rbrain-oracle`
- **THEN** the request SHALL reach the handler and produce either the 200 response defined below or the 404 response defined below; the gateway is NOT in the path (oracle is internal-only per `service-topology`)

#### Scenario: path parameter is opaque

- **WHEN** `{number}` is any non-empty string (not necessarily a well-formed MTG rule number like `100`, `100.1`, `702.21a`)
- **THEN** the endpoint SHALL NOT reject the request at the routing layer; the lookup proceeds and falls through to the 404 response when the number is unknown

### Requirement: 200 response carries the Rule payload

When the requested `number` matches a rule in the oracle store, the response SHALL be:

- Status: `200 OK`
- `Content-Type: application/json`
- Body: a JSON object with exactly the three fields below, in any key order:

| Field    | Type   | Description                                                                                                            |
|----------|--------|------------------------------------------------------------------------------------------------------------------------|
| `number` | string | The rule's canonical number, matching the path parameter (e.g. `"100.1"`, `"702.21a"`).                                |
| `text`   | string | The rule's body text, as published by Wizards of the Coast. Plain text, no Markdown, no HTML.                          |
| `source` | string | The document the rule comes from. At v1 the only allowed value is `"Comprehensive Rules"`.                             |

All fields are `string` at v1. Numeric or enum-typed fields are NOT introduced here; their addition (e.g. `parent`, `children`, `last_updated`) requires a MODIFIED delta on this requirement.

Concrete example for `number = "100.1"`:

```json
{
  "number": "100.1",
  "text": "These Magic rules apply to any Magic game with two or more players, including two-player games and multiplayer games.",
  "source": "Comprehensive Rules"
}
```

#### Scenario: rule 100.1 200 payload matches the example

- **WHEN** `GET /rules/100.1` is issued at v1
- **THEN** the body SHALL deserialize to a JSON object structurally equivalent to the example above, with the same three fields and `source: "Comprehensive Rules"`

#### Scenario: Extra fields are forbidden

- **WHEN** the 200 response body is parsed
- **THEN** it SHALL NOT carry any field outside the three listed above; adding a fourth field requires an OpenSpec change against this requirement

#### Scenario: All fields are strings

- **WHEN** the consumer parses the 200 body
- **THEN** every value SHALL be a JSON string; numbers, booleans, arrays, and nested objects are forbidden in v1

### Requirement: 404 response carries a structured error payload

When the requested `number` does NOT match any rule in the oracle store, the response SHALL be:

- Status: `404 Not Found`
- `Content-Type: application/json`
- Body: a JSON object with exactly the two fields below:

| Field    | Type   | Description                                          |
|----------|--------|------------------------------------------------------|
| `error`  | string | Constant value `"rule not found"`                    |
| `number` | string | The raw path parameter received by the handler       |

#### Scenario: Unknown number returns the canonical 404 shape

- **WHEN** `GET /rules/9999.9` is issued and no such rule exists
- **THEN** the body SHALL be `{"error": "rule not found", "number": "9999.9"}`; status SHALL be `404`

#### Scenario: Empty path parameter falls through to 404

- **WHEN** a request reaches the handler with an empty `{number}` (unusual routing edge case)
- **THEN** the response SHALL be the 404 payload with `number: ""`; the handler SHALL NOT 500

### Requirement: No other public HTTP routes at v1

`rbrain-oracle` SHALL expose exactly two **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`) and `GET /rules/{number}` (defined here). Any additional public route — listing endpoints, batch endpoints, semantic search endpoints, glossary endpoints, ruling endpoints, or new `/rules/*` subpaths — requires a MODIFIED delta on `oracle-api` before the route ships.

At v1, `rbrain-oracle` SHALL NOT expose any `/admin/*` route. Should an operator-only endpoint surface later (rules re-sync trigger, embeddings rebuild), an `/admin/*` carve-out comparable to `lexicon-api-admin-carveout` SHALL be introduced via its own OpenSpec change; only then are `/admin/*` routes permitted under this requirement.

#### Scenario: New public endpoint goes through OpenSpec

- **WHEN** a contributor adds `POST /rules/semantic-search` or `GET /glossary/{term}` to oracle
- **THEN** the change SHALL include a MODIFIED requirement on this spec; CI on oracle ALONE is not enough to make the new endpoint part of the public surface

#### Scenario: /health does not need an oracle-api requirement

- **WHEN** a contributor reads oracle-api/spec.md looking for `/health`
- **THEN** they SHALL find it referenced here as out-of-scope-for-this-capability and authoritative in `repository-conventions`; this spec SHALL NOT restate the `/health` contract

#### Scenario: Admin route requires a carve-out change first

- **WHEN** a contributor proposes `POST /admin/rules/resync` against oracle
- **THEN** the change SHALL include both a new `/admin/*` carve-out requirement on `oracle-api` (mirroring `lexicon-api-admin-carveout`) AND the per-endpoint spec; merging the endpoint without the carve-out SHALL fail the closure clause

