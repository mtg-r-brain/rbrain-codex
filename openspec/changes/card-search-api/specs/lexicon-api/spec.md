## ADDED Requirements

### Requirement: rbrain-lexicon exposes GET /cards search

`rbrain-lexicon` SHALL expose an HTTP endpoint at `GET /cards` accepting the following query parameters:

| Parameter | Type    | Default | Constraints                       | Description                                                |
|-----------|---------|---------|-----------------------------------|------------------------------------------------------------|
| `q`       | string  | none    | required, non-empty after trim    | Search query parsed by PostgreSQL's `websearch_to_tsquery` |
| `limit`   | integer | `20`    | `1 <= limit <= 100`               | Maximum results returned in this page                      |
| `offset`  | integer | `0`     | `offset >= 0`                     | Number of results to skip                                  |

The search SHALL match against the cards' `name`, `oracle_text`, and `type_line` fields. The exact `tsvector` build is implementation-defined in `rbrain-lexicon`'s own capability spec; the contract here is that the three fields participate in matching.

Results SHALL be ordered by `ts_rank` descending, with `name` ascending as a deterministic tiebreaker so paginated responses for the same `q` remain stable across requests.

#### Scenario: Successful search returns matching cards

- **WHEN** `GET /cards?q=lightning%20bolt` is issued
- **THEN** the response SHALL be HTTP 200 with a body matching the envelope below; the `results` array SHALL contain at least one card whose `name` or `oracle_text` contains "lightning" and "bolt"

#### Scenario: q semantics follow websearch_to_tsquery

- **WHEN** `GET /cards?q=%22lightning%20bolt%22` (URL-encoded phrase quotes) is issued
- **THEN** the matching SHALL prefer cards where the phrase appears as a unit; PostgreSQL's `websearch_to_tsquery` behavior governs the parse

#### Scenario: Pagination is stable across requests

- **WHEN** the same `q` is queried with `offset=0&limit=20` and then `offset=20&limit=20`
- **THEN** no card SHALL appear in both pages, AND no card matching the query SHALL be missing across the union of the two pages, AND the within-page order SHALL be deterministic (`ts_rank` desc, `name` asc)

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

- `q` missing, empty, or whitespace-only after trimming → `param: "q"`
- `limit` parses but is outside `[1, 100]` → `param: "limit"`
- `limit` does not parse as a non-negative integer → `param: "limit"`
- `offset` parses but is negative → `param: "offset"`
- `offset` does not parse as a non-negative integer → `param: "offset"`

The 400 response SHALL be `Content-Type: application/json`. The `error` strings are part of the contract; consumers MAY branch on them.

#### Scenario: Missing q returns 400 with named param

- **WHEN** `GET /cards` (no query string at all) is issued
- **THEN** the response SHALL be HTTP 400 with body `{"error": "q is required", "param": "q"}`

#### Scenario: Empty q returns 400

- **WHEN** `GET /cards?q=` or `GET /cards?q=%20%20` is issued
- **THEN** the response SHALL be HTTP 400 with body `{"error": "q must not be empty", "param": "q"}`

#### Scenario: Out-of-range limit returns 400

- **WHEN** `GET /cards?q=x&limit=200` is issued
- **THEN** the response SHALL be HTTP 400 with body `{"error": "limit must be between 1 and 100", "param": "limit"}`

#### Scenario: Negative offset returns 400

- **WHEN** `GET /cards?q=x&offset=-1` is issued
- **THEN** the response SHALL be HTTP 400 with body `{"error": "offset must be non-negative", "param": "offset"}`

## MODIFIED Requirements

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
