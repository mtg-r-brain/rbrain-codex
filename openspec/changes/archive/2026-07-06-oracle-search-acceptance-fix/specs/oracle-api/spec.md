## MODIFIED Requirements

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

The retriever is tuned for keyword-anchored queries; reformulating conversational questions into that shape is the calling agent's responsibility (cortex's `search_rules` tool), validated end-to-end through the chat loop.

#### Scenario: Keyword-anchored query retrieves the relevant rule

- **WHEN** `GET /rules/search?q=ward keyword pay mana or countered` runs against the synced corpus
- **THEN** the response SHALL be `200` and `results` SHALL rank the Ward rule (`702.21a`) first, each entry carrying `number`, `text`, and a descending `score`

#### Scenario: Missing query is rejected

- **WHEN** `GET /rules/search` is requested without `q` (or with a blank `q`)
- **THEN** the response SHALL be `400` with `param` equal to `"q"`

#### Scenario: No network at query time

- **WHEN** a search request is served while the host has no outbound network connectivity
- **THEN** the request SHALL still succeed — embedding inference is in-process
