## Why

`rbrain-forge`'s decklist parser never fails a request: an unreadable line is collected into
`ParsedDeck.errors` while every readable entry is still returned. `POST /decks/parse` returns that
array. The persistence routes **discard it** — `POST /decks` and `PUT /decks/{id}` respond with the
stored deck, which has no such field.

The consequence is a silent data loss on the path users actually take. Pasting a decklist whose
line 7 is malformed saves a deck missing that card, with a `201`/`200` and no indication anything was
dropped. `rbrain-app` currently compensates by re-implementing forge's grammar client-side
(`src/lib/deck-serialize.ts`) and refusing to submit — the only place today that can tell a user which
line was the problem, and a duplicate of a grammar it does not own.

## What Changes

- The full stored deck payload gains `errors`, an array of `{ line, content, reason }` — the same
  shape `POST /decks/parse` already returns.
- The field is **transactional, not stored**: the two write routes populate it from the parse they just
  performed when the request carried a `decklist`, and it is empty on every other response — reads,
  historical version fetches, and `name`/`format`/`status`-only updates. `design.md` records why
  persisting it would be wrong and what the resulting read-side ambiguity is.
- Errors stay **informational**: a decklist with unreadable lines still saves `201`/`200`. This
  matches `forge-deck-parsing`'s own "parsing never fails the request" stance and
  `POST /decks/analyze`'s `unresolved` list — forge reports what it observed rather than refusing the
  write.
- **BREAKING**: none. Additive to the response shape, no route added, no request body changed, no
  behaviour changed for a caller that ignores the field. `rbrain-cortex` already declares `errors`
  and tolerates unknown forge fields (`forge-payload-tolerance`, 2026-08-17), so forge may ship this
  in either order relative to its consumers.

## Capabilities

### Modified Capabilities

- `forge-api`: the full stored deck payload gains `errors`; the two write routes' descriptions state
  when it is populated and that it never fails the write.

## Impact

- `rbrain-codex`: `openspec/specs/forge-api/spec.md` only. No YAML source, no validator, no scaffold
  baseline.
- `rbrain-forge`: implements this next — both handlers graft the parse result's errors onto the
  returned payload. No migration and no `DeckStore` change: the field is never persisted.
- `rbrain-cortex`: none required. `StoredDeck` already declares the field.
- `rbrain-app`: consumes it in a later slice, at which point its client-side grammar duplicate stops
  blocking submission and becomes an optimistic warning.
