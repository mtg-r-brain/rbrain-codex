# lexicon-api — Delta

## MODIFIED Requirements

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
