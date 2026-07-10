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

`rbrain-oracle` SHALL expose exactly three **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `GET /rules/{number}`, and `GET /rules/search` (both defined here). Any additional public route — listing endpoints, batch endpoints, glossary endpoints, ruling endpoints, or new `/rules/*` subpaths — requires a MODIFIED delta on `oracle-api` before the route ships.

Routes under the reserved prefix `/admin/*` are **operator/platform-internal** and SHALL NOT count toward this constraint. Their existence does NOT require a MODIFIED on `oracle-api`. The shape and behavior of each `/admin/*` endpoint live in oracle's own capability specs (e.g. `comprehensive-rules-sync`'s `/admin/sync` lives in `rbrain-oracle`'s `openspec/specs/comprehensive-rules-sync/spec.md`).

`/admin/*` routes SHALL NOT be reachable through `rbrain-gateway`; gateway's ingress rules MUST reject any external request whose path begins with `/admin/`.

#### Scenario: New public route goes through OpenSpec

- **WHEN** a contributor proposes any public route beyond `GET /health`, `GET /rules/{number}`, and `GET /rules/search`
- **THEN** review SHALL require a MODIFIED delta on this requirement before the route ships

#### Scenario: Route ordering avoids the path collision

- **WHEN** `GET /rules/search` is requested
- **THEN** it SHALL be served by the search handler, never captured by `GET /rules/{number}` as a rule numbered "search"

### Requirement: Semantic rules search endpoint

`rbrain-oracle` SHALL expose `GET /rules/search` on its declared service port, answering natural-language queries over the Comprehensive Rules corpus by **hybrid retrieval**: semantic similarity fused with lexical full-text matching, so paraphrase and exact-term queries both rank well.

Query parameters:

- `q` (string, required) — the natural-language query. Missing, empty, or whitespace-only SHALL be rejected with `400 {"error": <message>, "param": "q"}`.
- `limit` (integer, optional) — number of results, in `[1, 20]`, default `5`. Malformed or out-of-bounds SHALL be rejected with `400 {"error": <message>, "param": "limit"}`.

The `200 OK` response SHALL be `Content-Type: application/json` with exactly three top-level fields:

| Field     | Type  | Description |
|-----------|-------|-------------|
| `results` | array | Up to `limit` entries `{number, text, score}`, ordered by `score` descending. `number` and `text` match the Rule payload of `GET /rules/{number}`; `score` is a relevance score in `[0, 1]` (fused ranking — not a raw cosine value). |
| `limit`   | integer | Echo of the effective `limit`. |
| `query`   | string  | Echo of `q`. |

Query embeddings SHALL be computed **in-process** (no network call to any embedding provider); the model, its dimensionality, the lexical index, and the fusion algorithm are `rbrain-oracle` sibling-spec concerns, not part of this cross-context contract. An empty result set (`results: []`) is a valid `200` — never a `404`.

Exact-term queries (verbatim rule phrases, keyword names) are first-class thanks to the lexical channel; reformulating conversational questions into keyword-anchored shape remains available to the calling agent (cortex's `search_rules` tool) as an optimization, not a prerequisite.

#### Scenario: Keyword-anchored query retrieves the relevant rule

- **WHEN** `GET /rules/search?q=ward keyword pay mana or countered` runs against the synced corpus
- **THEN** the response SHALL be `200` and `results` SHALL rank the Ward rule (`702.21a`) first, each entry carrying `number`, `text`, and a descending `score`

#### Scenario: Verbatim rule phrase anchors lexically

- **WHEN** `GET /rules/search?q=becomes the target of a spell or ability an opponent controls` runs against the synced corpus
- **THEN** the response SHALL be `200` and `results` SHALL rank rule `702.21a` first — the exact-phrase match anchors even where pure semantic neighbors compete

#### Scenario: Missing query is rejected

- **WHEN** `GET /rules/search` is requested without `q` (or with a blank `q`)
- **THEN** the response SHALL be `400` with `param` equal to `"q"`

#### Scenario: No network at query time

- **WHEN** a search request is served while the host has no outbound network connectivity
- **THEN** the request SHALL still succeed — embedding inference is in-process

