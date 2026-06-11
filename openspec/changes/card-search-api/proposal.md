## Why

`rbrain-lexicon` ships a real ingestion path (`scryfall-sync`) producing ~80k rows of MTG cards and a NATS publication path (`lexicon-events`) signalling every refresh. Its **public surface** still consists of two routes only: `GET /health` and `GET /cards/{scryfall_id}`. A consumer wanting to find "Lightning Bolt" today has no path to that card without already knowing its Scryfall id — the catalogue is reachable but unbrowsable.

Slice 5 in lexicon (`card-search`) adds the obvious next endpoint: a full-text search over `name`, `oracle_text`, and `type_line`. Like every public-route addition, the cross-context contract has to land in `rbrain-codex` first so any consumer (cortex's future agent tool, the eventual frontend) can rely on a stable shape. This change is that contract.

## What Changes

- Add a new requirement on `lexicon-api`: `GET /cards?q=<query>&limit=<n>&offset=<n>` returns a paginated array of cards plus a `has_more` flag.
- Specify the query semantics: `q` is parsed by PostgreSQL's `websearch_to_tsquery` (Google-style: phrases in quotes, OR keyword, `-` for negation); matches are ranked by `ts_rank`; results are ordered by rank descending, then `name` ascending as the deterministic tiebreaker.
- Specify pagination defaults: `limit` default `20`, max `100`; `offset` default `0`, no hard upper bound but consumers SHOULD prefer keeping it under a few thousand for latency.
- Specify response shape: `{"results": [Card], "has_more": bool, "limit": <n>, "offset": <n>}` where each Card uses the existing six-field lexicon-api DTO.
- Specify validation: missing or empty `q` returns `400 Bad Request` with the structured error shape; out-of-range `limit` returns `400`.
- Bump the "No other public HTTP routes" requirement from "exactly two" to "exactly three" to make room for the new endpoint.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lexicon-api`: add the GET /cards search requirement; bump the "exactly two public routes" cap to three.

## Impact

- **`rbrain-codex`**: two delta operations on `lexicon-api`'s spec — one ADDED Requirement for the search endpoint, one MODIFIED Requirement for the route-count cap.
- **`rbrain-lexicon`** (downstream): the slice 5 change `card-search` implements the spec — `tsvector` index migration, query handler, parsing, pagination.
- **`rbrain-cortex`** (future): the search endpoint becomes the second `lookup_card`-style tool to wire when cortex ships.
- **Convention spillover**: this is the first time a sibling adds a second public endpoint family. The pattern set here (`<context>-api` evolves additively with one new ADDED requirement per endpoint family + one MODIFIED on the route-count cap) repeats for every future addition.
- **Out of scope (non-goals)**:
  - Filters beyond `q` (set, colors, cmc, type). Deferred until consumer pressure justifies the expansion; each filter would be its own MODIFIED.
  - Cursor-based pagination. Deferred until offset latency becomes a real concern.
  - Result ranking customization (boost recent printings, downweight basic lands). Default `ts_rank` is enough at v1.
  - Total-count metadata in the response. Counting all matches requires a second query; consumers paginate with `has_more` instead.
  - Aggregate endpoints (`/cards/by-set/{code}`, `/cards/by-name/{prefix}`). Distinct route families that need their own ADDED requirements when they ship.
