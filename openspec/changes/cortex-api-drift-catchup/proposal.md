## Why

`cortex-api` describes the deck-analysis composition response as `deck = {id, name}`
and was last touched 2026-06-12. `rbrain-cortex` has since shipped two waves that
widened that `deck` object to four fields, both documented only in cortex's own
`deck-analysis-composition` capability:

- `cortex-deck-format` (2026-07-11) — `format` and `format_violations` on the
  `deck` object of `GET /decks/{deck_id}/analysis`.
- `forge-payload-tolerance` (2026-08-17) — restated the four-field `deck` object
  and pinned how it is built (from individual `StoredDeck` attributes, never
  `model_dump()`), so the endpoint's field set stays independent of forge's payload.

Neither wave broke the letter of the rule. `cortex-api`'s closure requirement gates
on a **new route**, and neither added one — they widened the shape of an existing
route's response, which the rule never mentioned. The gap is in the rule, not in the
changes that passed through it.

The cost is a stale contract. A cross-context consumer (the app, or a future
gateway-side reader) reading `cortex-api` is told `deck` carries exactly `{id, name}`
and is entitled to have read a true description of it — the same argument the
`forge-api-response-shape-catchup` change made for forge's payloads. The served
shape has been four fields for over a month.

## What Changes

- `cortex-api`'s "Deck analysis composition endpoint" requirement is brought level
  with what cortex actually serves: the `deck` object carries `format` (nullable
  string) and `format_violations` (`{name, status}` list, possibly empty) in
  addition to `id` and `name`.
- The round-trip scenario is widened to assert the two additional fields.
- **BREAKING**: none. Nothing about cortex's runtime behaviour changes; this change
  only makes the contract describe what is already served.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `cortex-api`: the deck-analysis composition requirement brought level with the
  served shape.

## Impact

- `rbrain-codex`: `openspec/specs/cortex-api/spec.md` only. No YAML source, no
  validator, no scaffold baseline — `bash scripts/validate-repo.sh .` is the only
  gate that applies.
- `rbrain-cortex`: none. Every field this change documents is already implemented
  and shipped.
- `rbrain-app`: none. Its TypeScript deck types are structural and already tolerate
  unknown fields.
