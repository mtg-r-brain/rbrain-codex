# lexicon-api — Delta

## MODIFIED Requirements

### Requirement: rbrain-lexicon exposes GET /cards search

`rbrain-lexicon` SHALL expose an HTTP endpoint at `GET /cards` accepting the following query parameters:

| Parameter | Type    | Default | Constraints                                  | Description                                                |
|-----------|---------|---------|----------------------------------------------|------------------------------------------------------------|
| `q`       | string  | none    | exactly one of `q`/`name`, non-empty (trim)  | Search query parsed by PostgreSQL's `websearch_to_tsquery` |
| `name`    | string  | none    | exactly one of `q`/`name`, non-empty (trim)  | Exact card-name lookup, case-insensitive equality          |
| `printing`| string  | `any`   | `any` \| `first`; `name` mode only           | Ordering policy over a name's printings                    |
| `limit`   | integer | `20`    | `1 <= limit <= 100`                          | Maximum results returned in this page                      |
| `offset`  | integer | `0`     | `offset >= 0`                                | Number of results to skip                                  |

With `q`, the search SHALL match against the cards' `name`, `oracle_text`, and `type_line` fields. The exact `tsvector` build is implementation-defined in `rbrain-lexicon`'s own capability spec; the contract here is that the three fields participate in matching. Results SHALL be ordered by `ts_rank` descending, with `name` ascending as a deterministic tiebreaker so paginated responses for the same `q` remain stable across requests. `printing` SHALL NOT be accepted with `q` (it is a printing-selection policy and full-text results are not a printing family); sending both SHALL produce the structured 400 described by "GET /cards validates query parameters".

With `name`, matching SHALL be case-insensitive equality on the `name` field alone — no tsquery parsing, no partial or fuzzy matching, no relevance ranking involved. The response envelope, pagination semantics, and `Card` payload are identical in both modes.

Ordering with `name` depends on `printing`:

- `printing=any` (default): results SHALL be ordered by `name` ascending then `scryfall_id` ascending, exactly as before this change (a deterministic constant for a given corpus; which printing comes first is an arbitrary function of the ids).
- `printing=first`: results SHALL be ordered by the **earliest-plain policy** — the first row is the oldest plain printing of the name. The ordering keys, applied in order, each preferring the listed side:
  1. `lang` equal to `"en"` before any other language;
  2. `set_type` NOT in the special-printing set `{promo, token, variant, memorabilia, meme, custom, version, box, bundle, code, draft_pool, arsenal, from_vault, premium, secret_lair, spellbook, trainer_kit}` before in-set;
  3. empty or absent `frame_effects` before non-empty;
  4. `released_at` ascending (rows whose `released_at` is absent sort last);
  5. `scryfall_id` ascending as the final deterministic tiebreaker.

  The policy is a pure ordering: it never filters the result set — printings failing a preference rank behind those passing it, so `results` stays non-empty whenever the name exists. Consumers SHALL read `results[0]` as the canonical display printing.

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

#### Scenario: printing=first surfaces the oldest plain printing

- **WHEN** `GET /cards?name=Lightning%20Bolt&printing=first` is issued against a corpus containing an 8th Edition core printing (`released_at` 2001-07-13, `set_type` core, no frame effects), a Legends expansion printing (`released_at` 1993-10-04, `set_type` expansion), a Serializer showcase printing (same `released_at` as the core one, `set_type` promo, `frame_effects` `["showcase"]`), and a Japanese printing of the core set (`lang` `ja`, same date)
- **THEN** `results[0]` SHALL be the Legends printing (non-special `set_type`, oldest `released_at`)

#### Scenario: printing=any keeps the legacy order

- **WHEN** `GET /cards?name=Lightning%20Bolt` is issued with no `printing` parameter, or with `printing=any`
- **THEN** the response SHALL be byte-identical to the response defined before this change (`name` asc, `scryfall_id` asc), and the policy ordering SHALL NOT be applied

#### Scenario: printing is rejected on the full-text mode

- **WHEN** `GET /cards?q=bolt&printing=first` is issued
- **THEN** the response SHALL be HTTP 400 with the structured error envelope and `param` set to `printing`

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
- `printing` provided but not one of `any` / `first` (exact, lower-case) → `param: "printing"`
- `printing` provided with `q` (printing is a `name`-mode policy) → `param: "printing"`

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

#### Scenario: Unknown printing policy returns 400

- **WHEN** `GET /cards?name=Island&printing=oldest` is issued
- **THEN** the response SHALL be HTTP 400 with a JSON body whose `param` field is `printing`
