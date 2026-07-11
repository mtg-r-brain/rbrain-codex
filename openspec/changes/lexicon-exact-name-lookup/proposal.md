# lexicon-exact-name-lookup

## Why

Cortex's card-fact resolver (the `analyze_deck` tool and the new deck-analysis endpoint) needs facts for names it already knows **exactly** — but lexicon only offers full-text search, so resolution depends on relevance ranking. Live smoke exposed the failure: `q=Island` ranks 13 art-series `Island // Island` printings (`type_line: Card // Card`) and other noise above the actual basic land, whose first exact hit sits at rank 23 — past the resolver's page size. Every real deck runs basic lands, so deck analysis visibly degrades (`unresolved: ["Island"]` or garbage `Other` type counts).

Using ranked search for exact lookup is the wrong tool. The contract gains a precise one.

## What Changes

- MODIFY `lexicon-api` › "rbrain-lexicon exposes GET /cards search": `GET /cards` accepts **exactly one of** `q` (full-text, unchanged semantics) or `name` (exact case-insensitive name equality — no tsquery involvement); `name` results order by `name` asc then `scryfall_id` asc (ts_rank is undefined for equality matches).
- MODIFY `lexicon-api` › "GET /cards validates query parameters": neither-or-both of `q`/`name` is a `400`; empty `name` is a `400 {param: "name"}`. The former `"q is required"` error string becomes `"exactly one of q or name is required"` (consumers MAY branch on error strings; the only in-cluster caller is cortex, which does not).
- No new route: the same `GET /cards` path serves both modes, so the gateway's public surface and route closure are untouched (a `GET /cards/by-name/{name}` route was rejected for exactly that reason — it would ride the gateway's `/cards/*` proxy into the public surface uninvited).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lexicon-api`: `GET /cards` gains the exact-name lookup mode.

## Impact

- Sibling implementation in `rbrain-lexicon` (param parsing + one `WHERE lower(name) = lower($1)` query path).
- Consumer follow-up in `rbrain-cortex` (resolver tries `name=` first, falls back to full-text + front-face matching for cards referenced by their front face).
- Envelope, pagination, and `q` semantics are byte-compatible for existing callers.
