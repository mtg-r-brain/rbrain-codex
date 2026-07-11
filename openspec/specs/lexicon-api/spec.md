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

`rbrain-lexicon` SHALL expose exactly three **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `GET /cards/{scryfall_id}` (defined here), and `GET /cards` (the search endpoint defined above). Any additional public route — other list endpoints, batch endpoints, aggregate endpoints, or new `/cards/*` subpaths — requires a MODIFIED delta on `lexicon-api` before the route ships.

Routes under the reserved prefix `/admin/*` are **operator/platform-internal** and SHALL NOT count toward this constraint. Their existence does NOT require a MODIFIED on `lexicon-api`. The shape and behavior of each `/admin/*` endpoint live in lexicon's own capability specs (e.g. `scryfall-sync`'s `/admin/sync` lives in `rbrain-lexicon`'s `openspec/specs/scryfall-sync/spec.md`).

`/admin/*` routes SHALL NOT be reachable through `rbrain-gateway` once gateway routing ships; gateway's ingress rules MUST reject any external request whose path begins with `/admin/`. Until gateway exists, lexicon's internal-only status (per `service-topology`'s sync graph) is the implicit protection.

#### Scenario: New public endpoint goes through OpenSpec

- **WHEN** a contributor adds `GET /cards/by-name/{name}` to lexicon
- **THEN** the change SHALL include a MODIFIED requirement on this spec; CI on lexicon ALONE is not enough to make the new endpoint part of the public surface

#### Scenario: Admin endpoint does not need a codex spec change

- **WHEN** a contributor adds `POST /admin/sync` (or any other `/admin/*` route) to lexicon
- **THEN** the change SHALL NOT require a MODIFIED on `lexicon-api`; the endpoint's behavior is captured in lexicon's own capability spec, and gateway's routing rules ensure the endpoint is not reachable from outside the cluster

#### Scenario: Gateway rejects external admin traffic

- **WHEN** `rbrain-gateway` (once shipped) receives an external request with a path matching `^/admin/`
- **THEN** the gateway SHALL respond with HTTP 404 (or another suitable status) without forwarding the request to lexicon; the gateway-side routing rules SHALL enforce this regardless of method

### Requirement: rbrain-lexicon exposes GET /cards search

`rbrain-lexicon` SHALL expose an HTTP endpoint at `GET /cards` accepting the following query parameters:

| Parameter | Type    | Default | Constraints                                  | Description                                                |
|-----------|---------|---------|----------------------------------------------|------------------------------------------------------------|
| `q`       | string  | none    | exactly one of `q`/`name`, non-empty (trim)  | Search query parsed by PostgreSQL's `websearch_to_tsquery` |
| `name`    | string  | none    | exactly one of `q`/`name`, non-empty (trim)  | Exact card-name lookup, case-insensitive equality          |
| `limit`   | integer | `20`    | `1 <= limit <= 100`                          | Maximum results returned in this page                      |
| `offset`  | integer | `0`     | `offset >= 0`                                | Number of results to skip                                  |

With `q`, the search SHALL match against the cards' `name`, `oracle_text`, and `type_line` fields. The exact `tsvector` build is implementation-defined in `rbrain-lexicon`'s own capability spec; the contract here is that the three fields participate in matching. Results SHALL be ordered by `ts_rank` descending, with `name` ascending as a deterministic tiebreaker so paginated responses for the same `q` remain stable across requests.

With `name`, matching SHALL be case-insensitive equality on the `name` field alone — no tsquery parsing, no partial or fuzzy matching, no relevance ranking involved. Results SHALL be ordered by `name` ascending then `scryfall_id` ascending (`ts_rank` is undefined for equality matches; the order is a deterministic constant for a given corpus). The response envelope, pagination semantics, and `Card` payload are identical in both modes.

#### Scenario: Successful search returns matching cards

- **WHEN** `GET /cards?q=lightning%20bolt` is issued
- **THEN** the response SHALL be HTTP 200 with a body matching the envelope below; the `results` array SHALL contain at least one card whose `name` or `oracle_text` contains "lightning" and "bolt"

#### Scenario: q semantics follow websearch_to_tsquery

- **WHEN** `GET /cards?q=%22lightning%20bolt%22` (URL-encoded phrase quotes) is issued
- **THEN** the matching SHALL prefer cards where the phrase appears as a unit; PostgreSQL's `websearch_to_tsquery` behavior governs the parse

#### Scenario: Pagination is stable across requests

- **WHEN** the same `q` is queried with `offset=0&limit=20` and then `offset=20&limit=20`
- **THEN** no card SHALL appear in both pages, AND no card matching the query SHALL be missing across the union of the two pages, AND the within-page order SHALL be deterministic (`ts_rank` desc, `name` asc)

#### Scenario: Exact-name lookup ignores relevance noise

- **WHEN** `GET /cards?name=Island` is issued against a corpus containing printings named `Island` and art-series printings named `Island // Island`
- **THEN** the response SHALL be HTTP 200 and every entry in `results` SHALL have `name` exactly equal to `Island` (case-insensitively); no `Island // Island` printing SHALL appear

#### Scenario: Exact-name lookup is case-insensitive

- **WHEN** `GET /cards?name=lightning%20BOLT` is issued
- **THEN** the `results` SHALL be the same set as for `name=Lightning%20Bolt`

### Requirement: GET /cards response envelope

The 200 response from `GET /cards` SHALL carry:

- Status: `200 OK`
- `Content-Type: application/json`
- Body matching exactly the four top-level fields below:

| Field      | Type            | Description                                                       |
|------------|-----------------|-------------------------------------------------------------------|
| `results`  | array of Card   | Up to `limit` matching cards, ordered per the requirement above   |
| `has_more` | boolean         | `true` iff at least one more card exists after the returned page  |
| `limit`    | integer         | Echo of the `limit` that produced this page                       |
| `offset`   | integer         | Echo of the `offset` that produced this page                      |

Each entry in `results` SHALL be a `Card` exactly as defined by the existing "200 response carries the Card payload" requirement — the six string fields `scryfall_id`, `oracle_id`, `name`, `mana_cost`, `type_line`, `oracle_text`. No additional fields per result; ranking score is NOT exposed at v1.

Concrete example for a search returning two cards on a non-final page:

```json
{
  "results": [
    {
      "scryfall_id": "...",
      "oracle_id": "...",
      "name": "Lightning Bolt",
      "mana_cost": "{R}",
      "type_line": "Instant",
      "oracle_text": "Lightning Bolt deals 3 damage to any target."
    },
    {
      "scryfall_id": "...",
      "oracle_id": "...",
      "name": "Lightning Strike",
      "mana_cost": "{1}{R}",
      "type_line": "Instant",
      "oracle_text": "Lightning Strike deals 3 damage to any target."
    }
  ],
  "has_more": true,
  "limit": 20,
  "offset": 0
}
```

#### Scenario: Empty result is a valid response

- **WHEN** `q` matches no cards
- **THEN** the response SHALL be HTTP 200 with `"results": []`, `"has_more": false`, and the echoed `limit` and `offset`

#### Scenario: has_more reflects pagination reality

- **WHEN** a search would match exactly `limit` cards
- **THEN** `has_more` SHALL be `false`; when the match count is at least `limit + 1`, `has_more` SHALL be `true`

#### Scenario: No ranking metadata is exposed

- **WHEN** the response body is parsed
- **THEN** each entry in `results` SHALL carry only the six Card fields; no `rank`, `score`, or implementation-specific debug field SHALL appear

### Requirement: GET /cards validates query parameters

`GET /cards` SHALL reject the following inputs with HTTP `400 Bad Request` and a JSON body matching `{"error": "<message>", "param": "<offending param name>"}`:

- neither `q` nor `name` provided → `{"error": "exactly one of q or name is required", "param": "q"}`
- both `q` and `name` provided → `{"error": "q and name are mutually exclusive", "param": "name"}`
- `q` provided but empty or whitespace-only after trimming → `param: "q"`
- `name` provided but empty or whitespace-only after trimming → `param: "name"`
- `limit` parses but is outside `[1, 100]` → `param: "limit"`
- `limit` does not parse as a non-negative integer → `param: "limit"`
- `offset` parses but is negative → `param: "offset"`
- `offset` does not parse as a non-negative integer → `param: "offset"`

The 400 response SHALL be `Content-Type: application/json`. The `error` strings are part of the contract; consumers MAY branch on them.

#### Scenario: Missing q and name returns 400 with named param

- **WHEN** `GET /cards` (no query string at all) is issued
- **THEN** the response SHALL be HTTP 400 with body `{"error": "exactly one of q or name is required", "param": "q"}`

#### Scenario: Empty q returns 400

- **WHEN** `GET /cards?q=` or `GET /cards?q=%20%20` is issued
- **THEN** the response SHALL be HTTP 400 with body `{"error": "q must not be empty", "param": "q"}`

#### Scenario: Empty name returns 400

- **WHEN** `GET /cards?name=` or `GET /cards?name=%20%20` is issued
- **THEN** the response SHALL be HTTP 400 with body `{"error": "name must not be empty", "param": "name"}`

#### Scenario: Both q and name returns 400

- **WHEN** `GET /cards?q=bolt&name=Lightning%20Bolt` is issued
- **THEN** the response SHALL be HTTP 400 with body `{"error": "q and name are mutually exclusive", "param": "name"}`

#### Scenario: Out-of-range limit returns 400

- **WHEN** `GET /cards?q=x&limit=200` is issued
- **THEN** the response SHALL be HTTP 400 with body `{"error": "limit must be between 1 and 100", "param": "limit"}`

#### Scenario: Negative offset returns 400

- **WHEN** `GET /cards?q=x&offset=-1` is issued
- **THEN** the response SHALL be HTTP 400 with body `{"error": "offset must be non-negative", "param": "offset"}`

