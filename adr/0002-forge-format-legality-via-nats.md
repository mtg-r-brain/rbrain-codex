# ADR 0002 — Forge maintains its own format-legality view via NATS events

- **Status**: Accepted (2026-07-11)
- **Deciders**: Hoani Cross (owner), via strategic-fork review
- **Tracked as**: multi-format support kickoff (vision feature, backlog item since 2026-07-11 checkpoint)

## Context

`lexicon` owns the card catalogue synced from Scryfall; `raw_scryfall` (jsonb,
`0002_add_raw_scryfall_to_card.sql`) carries the full Scryfall payload,
including `legalities`, but `lexicon` explicitly excludes "deck legality
enforcement" from its responsibilities (`bounded-contexts/catalog.yaml:42`).
`forge` already owns the term `format-legality` (`catalog.yaml:78`) as part of
"Parses, stores, and analyzes Magic decks across all supported formats", but
today has no `format` field on `Deck` and no source for legality data.

A prior deck-CRUD checkpoint (2026-06-17) flagged this gap explicitly: *"deck
legality/analysis (needs lexicon edge from forge? not allowed — would be
cortex-mediated)"*. This confirms the platform's standing convention: peer
bounded contexts do not call each other synchronously; only `cortex`
orchestrates cross-context calls at request time (`lexicon`, `oracle`, `forge`
are tools of `cortex`, never of each other — dependency graph in
`ideas/02-repositories.md`).

## Decision

`forge` maintains its own local read-model of card format-legalities,
populated by **consuming NATS events published by `lexicon`** — a
materialized-view pattern, consistent with the `identity-events` →
`cortex` consumer precedent shipped 2026-06-14.

1. `lexicon` publishes per-card legality data (parsed out of
   `raw_scryfall.legalities`), keyed by `oracle_id`/`scryfall_id`, on NATS.
   Exact stream/subject and bulk-replay-vs-incremental shape are decided in
   the `lexicon`-side OpenSpec change (slice 1).
2. `forge` subscribes and persists a local `format_legality` store. It never
   queries `lexicon` directly, synchronously or otherwise.
3. `forge` gains a `format` field on `Deck` and validates legality at
   parse/persist time using only its own local copy.
4. `cortex`'s `parse_deck`/`analyze_deck` tools gain a `format` parameter that
   is forwarded to `forge` as-is — no legality data flows through `cortex`.

## Consequences

**Positive**: preserves bounded-context autonomy (`forge` owns
`format-legality` end-to-end, per the catalog); no new synchronous edge
between peer contexts; deck analysis latency and availability stay
independent of `lexicon`; reuses an operational pattern the team already
knows how to run (NATS consumer + local store).

**Negative / cost**: eventual consistency — a legality change in `lexicon`
reaches `forge` one event round-trip later (acceptable: legality changes on
banned-list announcement cadence, not real-time); needs a new NATS
stream/subject with a canonical port, mind Finding B (port-mapping
convention) already flagged platform-wide; `forge` needs a full historical
backfill path for ~115k cards on first bring-up, not just an incremental feed
going forward — the `lexicon`-side change must define bulk replay, not only
future-diff events.

**Work items** (queued as the next chantier, spec-first, tracer-bullet
slicing):

- `rbrain-lexicon` OpenSpec change (slice 1): parse `legalities` out of
  `raw_scryfall`, publish on NATS (bulk replay for existing catalogue +
  incremental on future syncs).
- `rbrain-forge` OpenSpec change (slice 2): `format_legality` local store,
  NATS consumer, `Deck.format` field, validation at parse/persist.
- `rbrain-cortex` (slice 3): `format` parameter threaded through
  `parse_deck`/`analyze_deck` tool schemas.
- `rbrain-app` (slice 4): format selector in the deck UI.

## Alternatives considered

- **Direct synchronous `forge → lexicon` call**: rejected — breaks the
  existing cross-context calling convention (only `cortex` orchestrates), and
  was already flagged as "not allowed" in a prior working session.
- **`cortex`-mediated legality lookup** (fetch from `lexicon` per call, pass
  into `forge`): rejected — keeps `forge` stateless but reintroduces a live
  dependency on `cortex`+`lexicon` uptime for every deck operation, duplicates
  orchestration logic at every call site, and contradicts `forge`'s stated
  ownership of `format-legality` in the bounded-context catalog.
