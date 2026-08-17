## Why

`forge-api` describes the deck-persistence response as eight fields
(`{ id, name, mainboard, sideboard, commander, maybeboard, total_mainboard, created_at }`)
and was last touched 2026-07-06. `rbrain-forge` has since shipped three waves that widened
that response to twelve fields and widened two request bodies, all documented only in forge's
own `forge-deck-persistence` capability:

- `forge-format-legality` (2026-07-11) — `format` and `format_violations` on every deck response;
  `format` accepted on `POST`/`PUT` bodies.
- `forge-legality-format-expansion` (2026-07-12) — the accepted `format` value set widened.
- `deck-draft-versions` (2026-08-16) — `status` and `version` on every deck response; `status`
  accepted on `POST`/`PUT` bodies; `?version=N` accepted on `GET /decks/{id}`.

None of those changes broke the letter of the rule. `forge-api`'s closure requirement and
`AGENTS.md` both gate on a **new route**, and none of the three added one — they extended bodies
and response shapes on the existing eight paths, which the rule never mentioned. The gap is in
the rule, not in the changes that passed through it.

The cost is already measurable. `rbrain-cortex` mirrors this contract as a Pydantic model with
`extra="forbid"`, so each widening wave has been a latent production break in cortex, caught by
hand each time — `deck-analysis-composition` carries a scenario for the `format`/`format_violations`
pair, and `build-deck-tool` had to ship a `StoredDeck` field addition in lockstep for
`status`/`version`. The next widening (surfacing the parser's per-line `errors` on the write
routes, the change this one clears the way for) would be the third repetition of the same fix.

## What Changes

- `forge-api`'s two persistence requirements are brought level with what forge actually serves:
  the four additional response fields, the two additional request-body fields, and the
  `?version=N` query parameter on `GET /decks/{id}`.
- `forge-api`'s closure requirement is widened from "no new route without a delta" to cover
  **response-shape and request-body changes on the existing routes** — the class of change that
  slipped through three times.
- A new requirement fixes the compatibility posture between forge and its consumers: an additive
  response field is a documented, delta-gated change on forge's side, **and** consumers ignore
  unknown fields rather than rejecting them. Both halves, because the rule alone demonstrably did
  not hold, and tolerance alone would let the contract drift silently.
- **BREAKING**: none. Nothing about forge's runtime behaviour changes; this change only makes the
  contract describe what is already served, and states a rule for the next widening.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `forge-api`: persistence and update requirements brought level with the served shape; closure
  requirement widened to response shapes and request bodies; consumer-tolerance requirement added.

## Impact

- `rbrain-codex`: `openspec/specs/forge-api/spec.md` only. No YAML source, no validator, no
  scaffold baseline — `bash scripts/validate-repo.sh .` is the only gate that applies.
- `rbrain-forge`: none. Every field this change documents is already implemented and shipped.
- `rbrain-cortex`: no change *required by this document*, but it is the consumer the new tolerance
  requirement addresses; the corresponding `extra="ignore"` move ships as its own change (see
  `design.md`, Decision 3).
- `rbrain-app`: none. Its TypeScript deck types are structural and already tolerate unknown fields.
