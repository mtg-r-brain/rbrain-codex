# Proposal — lexicon-printing-ordering

## Why

Every card name in Scryfall is a family of printings — `Lightning Bolt` has 72
rows in the lexicon mirror — and the platform has no way to ask *which* printing
it is getting. The `name` mode of `GET /cards` returns all printings ordered by
`(name, scryfall_id)`; the id is a UUID, so "first result" is a lottery over
printings. Consumers already pick `results[0]` — the app's card-metadata cache
renders a hover image from whichever printing won the sort, which is often a
foil showcase or a Serializer promo.

The oldest, plainest printing is the right platform default for display: it is
the canonical face of the card, and it structurally cannot be a special edition.
The data is already there: the mirror's `raw_scryfall` carries `released_at`,
`set_type`, `lang`, and `frame_effects` for 115 819 of 115 826 rows — no sync
change, no backfill, no new storage. What is missing is a policy knob on the
existing route.

## What Changes

- `lexicon-api`: the `name` mode of `GET /cards` gains an optional `printing`
  parameter. `printing=any` (default) keeps today's behavior verbatim.
  `printing=first` returns the same envelope but orders results by the
  **earliest-plain policy**: English language first, non-special `set_type`
  first, empty `frame_effects` first, then oldest `released_at`, then
  `scryfall_id` — so `results[0]` is the oldest plain printing of the name,
  with a graceful fallback (rows failing a preference simply rank last, the
  result set never empties because of the policy).
- The validation requirement gains the matching 400 for a malformed `printing`
  value (`param: "printing"`), same structured envelope as the other params.
- `q` mode is untouched. The gateway needs no change: it forwards the query
  string verbatim.

## Non-goals

- No new fields on the `Card` payload (the six-string closure stands).
- No new route, no printing *listing* endpoint — this is an ordering policy,
  not a catalog read.
- No change to which printings the sync ingests (all of them, as today).

## Impact

- Affected specs: `lexicon-api` (two MODIFIED requirements).
- Affected code: `rbrain-lexicon` (query ordering + param validation, Postgres
  and in-memory stores), then an `rbrain-app` slice that opts into
  `printing=first` for hover previews (chat and deck editor).
- Backward compatible: default `any` preserves every existing consumer's
  behavior byte-for-byte.
