## ADDED Requirements

### Requirement: Semantic rules search endpoint

`rbrain-oracle` SHALL expose `GET /rules/search` on its declared service port, answering natural-language queries over the Comprehensive Rules corpus by semantic similarity.

Query parameters:

- `q` (string, required) — the natural-language query. Missing, empty, or whitespace-only SHALL be rejected with `400 {"error": <message>, "param": "q"}`.
- `limit` (integer, optional) — number of results, in `[1, 20]`, default `5`. Malformed or out-of-bounds SHALL be rejected with `400 {"error": <message>, "param": "limit"}`.

The `200 OK` response SHALL be `Content-Type: application/json` with exactly three top-level fields:

| Field     | Type  | Description |
|-----------|-------|-------------|
| `results` | array | Up to `limit` entries `{number, text, score}`, ordered by `score` descending. `number` and `text` match the Rule payload of `GET /rules/{number}`; `score` is the semantic similarity in `[0, 1]`. |
| `limit`   | integer | Echo of the effective `limit`. |
| `query`   | string  | Echo of `q`. |

Query embeddings SHALL be computed **in-process** (no network call to any embedding provider); the model, its dimensionality, and the pgvector storage/indexing details are `rbrain-oracle` sibling-spec concerns, not part of this cross-context contract. An empty result set (`results: []`) is a valid `200` — never a `404`.

#### Scenario: Natural-language query retrieves the relevant rule

- **WHEN** `GET /rules/search?q=why is my spell countered unless I pay mana` runs against the synced corpus
- **THEN** the response SHALL be `200` and `results` SHALL contain the Ward rule (`702.21a`) among the top entries, each entry carrying `number`, `text`, and a descending `score`

#### Scenario: Missing query is rejected

- **WHEN** `GET /rules/search` is requested without `q` (or with a blank `q`)
- **THEN** the response SHALL be `400` with `param` equal to `"q"`

#### Scenario: No network at query time

- **WHEN** a search request is served while the host has no outbound network connectivity
- **THEN** the request SHALL still succeed — embedding inference is in-process

## MODIFIED Requirements

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
