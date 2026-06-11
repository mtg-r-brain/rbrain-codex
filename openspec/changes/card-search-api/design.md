## Context

`lexicon-api` has been doc-only since it shipped: one endpoint, one payload shape, one error shape. Slice 5 in `rbrain-lexicon` is the first time the API needs to grow. This change captures the cross-context contract for the new endpoint and freezes the pattern for additive growth so subsequent slices (search filters, aggregate endpoints, future families) can follow the same playbook.

Stakeholders: `rbrain-lexicon` (the producer about to implement); `rbrain-cortex` (will consume the search endpoint as an agent tool); any future contributor adding a sibling endpoint family — this change is their template.

## Goals / Non-Goals

**Goals:**

- Lock the search endpoint's path, params, semantics, and response shape so the lexicon implementation has a single source of truth to satisfy.
- Establish the additive-growth pattern: one ADDED requirement per new endpoint family + one MODIFIED on the route-count cap.
- Keep the contract specific enough to be testable from the consumer side (cortex's future contract test).

**Non-Goals:**

- Specifying filters beyond `q`. Set, colors, cmc, type are obviously useful but each one is its own contract decision; defer until consumer-side pressure makes the trade-offs clear.
- Cursor pagination. Postgres offset is fine at v1's scale; switching schemes when needed is one more MODIFIED.
- Ranking knobs (boost, downweight). Default `ts_rank` is enough — and changing default ranking is a contract-visible change, so we want to think carefully before adding knobs.
- Total-count metadata. Counting matches doubles the database work; consumers paginate with `has_more`.

## Decisions

### D1. `GET /cards?q=<query>&limit=<n>&offset=<n>`

The path is `/cards` (no trailing segment) to distinguish from the existing `GET /cards/{scryfall_id}` lookup. Axum routes them separately because the lookup carries a path param and the search does not.

The three query params:

- `q` (string, required): the search query. Empty or absent → `400 Bad Request`.
- `limit` (integer, optional, default `20`, max `100`): pagination window size. Above `100` → `400 Bad Request`.
- `offset` (integer, optional, default `0`): how many results to skip. No hard upper bound, but performance degrades as offset grows.

**Rationale:** RESTful query-string parameters are cacheable and easy to compose into a URL by hand for debugging. The hard cap on `limit` prevents accidental "give me everything" requests that would force the DB to materialize huge result sets.

**Alternatives considered:**

- **`POST /cards/search` with a JSON body** — rejected: not cacheable, harder to debug, opens the door to "ask for anything" rich filters before we've earned the maturity to design them.
- **Cursor pagination via `cursor=<opaque>`** — rejected at v1: offset-based is simpler for the consumer and at our scale of ~80k rows offset performance is fine. Switch when the threshold bites.
- **`q` defaults to listing everything** — rejected: makes the endpoint dual-purpose (list + search), confuses semantics, and risks accidental full-table dumps.

### D2. Query semantics via `websearch_to_tsquery`

PostgreSQL's `websearch_to_tsquery` parses Google-style queries:

- `red dragon` → `red & dragon` (default AND across words)
- `"lightning bolt"` → phrase match
- `lightning OR bolt` → OR (the `OR` keyword is the only one)
- `lightning -bolt` → AND NOT
- Stop words (`the`, `a`, `of`) are filtered by the configured dictionary

**Rationale:** Familiar UX for anyone who has used a search engine. PostgreSQL ships this parser; we don't roll our own.

**Alternatives considered:**

- **`plainto_tsquery`** (simple words AND-ed, no operators) — rejected: too primitive; consumers will eventually want quoted phrases.
- **`to_tsquery`** (raw PostgreSQL tsquery syntax) — rejected: hostile UX; users would write `lightning & bolt`.
- **Custom Rust-side parser** — rejected: redundant with what Postgres ships.

### D3. Ranking by `ts_rank`, tiebreak by `name ASC`

Results are ordered by `ts_rank(tsv, websearch_to_tsquery('english', q))` descending. Ties on rank are broken by `name ASC` so paginated results stay stable across requests with the same `q`.

**Rationale:** `ts_rank` is the default Postgres ranking function; it weighs term frequency and proximity. Deterministic tiebreak prevents the "this card jumped pages" frustration.

**Alternatives considered:**

- **`ts_rank_cd` (cover-density variant)** — rejected at v1: marginal quality difference; `ts_rank` is the obvious starting point.
- **Tiebreak by `scryfall_id`** — rejected: visually arbitrary order ("why is the random UUID first?"); name tiebreak reads better in a UI.

### D4. Response shape: `{results, has_more, limit, offset}`

```json
{
  "results": [ /* array of Card; same six-field shape as GET /cards/{id} */ ],
  "has_more": true,
  "limit": 20,
  "offset": 0
}
```

- `results`: array (possibly empty). Each entry is the existing Card DTO — six string fields per `lexicon-api`'s base requirement.
- `has_more`: `true` if at least one more page exists after this one. Computed cheaply by asking the DB for `limit + 1` rows and dropping the last.
- `limit` and `offset`: echo the parameters that produced the page, so a client building "next" links does not need to remember what it asked for.

No `total` field — counting all matches would be a second query and is rarely worth the cost at v1.

**Rationale:** Minimal, debuggable, future-additive. New top-level fields (e.g. `total`, `next_cursor`) are additive evolutions that can land via MODIFIED.

**Alternatives considered:**

- **Bare array `[Card]` at the top level** — rejected: no room for `has_more`, makes future additions breaking changes.
- **`{data, meta}` envelope** — rejected: extra nesting without enough payoff at v1.

### D5. Validation errors mirror the existing 404 shape

Invalid `q` (absent or empty) or out-of-range `limit` return:

- Status: `400 Bad Request`
- `Content-Type: application/json`
- Body: `{"error": "<short message>", "param": "<offending param>"}`

The `error` strings are part of the contract — clients can branch on them — but the exact list grows additively (each new validation produces a new error string).

**Rationale:** Symmetric with the existing 404 shape (`{error, scryfall_id}`); cheap to extend; matches consumer expectations from the existing endpoints.

**Alternatives considered:**

- **RFC 7807 `application/problem+json`** — rejected at v1: over-engineered for two fields.
- **Plain text errors** — rejected: forces consumers to special-case content type.

### D6. The route-count cap goes from "exactly two" to "exactly three"

The existing requirement caps public routes at two (`/health` + `/cards/{scryfall_id}`). The search endpoint is the third. The MODIFIED requirement bumps the count and adds the new path family to the enumeration.

**Rationale:** Honesty about the surface; future contributors see the new shape immediately. The cap itself stays in place as the explicit-evolution gate.

**Alternatives considered:**

- **Drop the cap entirely** — rejected: the cap is the OpenSpec hook that forces every new public endpoint through a MODIFIED. Removing it would let routes silently proliferate.

## Risks / Trade-offs

- **Offset latency on large pages.** PostgreSQL has to skip `offset` rows before returning results; at offsets of tens of thousands this gets slow. Mitigation: the cap on `limit` (100) keeps page size bounded; offset pagination is documented as suitable for shallow browsing. Cursor pagination lands when telemetry shows the issue.
- **Ranking quality.** `ts_rank` is decent but not great for MTG queries ("dragon" doesn't preferentially surface dragons vs. cards mentioning dragons). Mitigation: accept it at v1; ranking customization is a future MODIFIED informed by real usage.
- **Stop word loss.** `websearch_to_tsquery` filters stop words per the english dictionary. `the brass squire` becomes `brass & squire`. Acceptable at v1 — and MTG has few names that depend on stop words.
- **Schema growth pressure.** Search hits `name`, `oracle_text`, `type_line`. When consumers later want to search `flavor_text` or `keywords`, the `tsvector` generated column has to grow. Acceptable: it is a sibling-local migration (no codex change required) as long as the contract here keeps `q` semantics opaque.
- **Cap-bumping MODIFIED ritual.** Every new endpoint family requires bumping the cap. Mild annoyance; intentional friction so contributors think twice before adding routes.

## Migration Plan

No code in this change. The MODIFIED + ADDED deltas archive into `openspec/specs/lexicon-api/spec.md`; `rbrain-lexicon`'s next change implements the spec.

Rollback: revert the codex commit; if `rbrain-lexicon`'s implementation already shipped, drop the route and back out the migration.

## Open Questions

- **Language config for the tsvector**: `english` is the obvious default given MTG's primary language, but multilingual support eventually matters. Defer to lexicon's implementation; the contract leaves it implementation-defined.
- **HEAD `/cards` support**: a HEAD request to the search endpoint would let clients pre-check if anything matches without paying for the body. Not in v1.
- **Caching headers**: `Cache-Control: public, max-age=...` on search responses could relieve hot queries. Defer to a future ops slice; the contract does not pin headers beyond `Content-Type`.
