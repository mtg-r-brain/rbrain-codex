## Context

The drift is one-directional and entirely in the `deck` object of a single route —
the route set never moved, and the `analysis` object never moved. Verified against
`rbrain-cortex` at main:

| Element | `cortex-api` says | cortex serves | Documented in |
|---|---|---|---|
| `GET /decks/{deck_id}/analysis` → `deck` | `{id, name}` | `{id, name, format, format_violations}` | `deck-analysis-composition` only |
| `GET /decks/{deck_id}/analysis` → `analysis` | six fields | six fields | in sync |
| Route set | three paths | three paths | in sync |

`analysis` is worth noting as the control case: the six forge analysis fields were
never widened, so the drift is specific to the `deck` object rather than a general
laxity about this contract.

The served types, from `rbrain-cortex/app/forge/types.py`:

- `format`: `str | None` — the deck's chosen format, or `null` when none is set.
- `format_violations`: `list[FormatViolation]` where `FormatViolation = {name, status}`
  and `status` is one of `not_legal` / `restricted` / `banned`; `[]` when no format
  is set or none is violated.

Two facts shape the decisions below.

1. **The rule that was supposed to catch this gates on routes.** `cortex-api`'s
   closure requirement says "any additional route … requires a MODIFIED delta", and
   `AGENTS.md` says "when a sibling ships a new public **endpoint**". A response-shape
   widening satisfies both by saying nothing — the identical gap `forge-api-response-shape-catchup`
   closed for forge's payloads on 2026-08-17.

2. **The consumer half of the tolerance rule already covers this class of change.**
   `repository-conventions` now states (via `consumer-tolerance-convention`, 2026-08-23)
   that an additive response field is delta-gated on the producer's side *and* tolerated
   on the consumer's side. This change is the producer half for cortex: it makes the
   contract true again. The consumer half is already in force platform-wide.

## Goals / Non-Goals

**Goals:**
- Make `cortex-api` describe the `deck` object cortex actually serves, so the next
  delta is written against a true baseline rather than a month-old one.
- Close the rule gap for this contract the way `forge-api-response-shape-catchup`
  closed it for forge's: response shapes are gated, not only paths.

**Non-Goals:**
- No behaviour change in cortex. Every field documented here already ships.
- No new scenario for the tolerance posture — that is `repository-conventions`'
  platform-wide rule, not restated per capability (per `consumer-tolerance-convention`).
- No CI validator for response-shape drift. Worth wanting, needs a machine-readable
  response schema that this contract does not have; already recorded as a follow-up
  by `forge-api-response-shape-catchup`.

## Decisions

**1. The `deck` object is enumerated field by field, matching the served shape.**
The delta replaces `{id, name}` with the four-field object and states the types of
the two added fields (`format`: nullable string; `format_violations`: `{name, status}`
list, possibly empty). The `status` value set (`not_legal` / `restricted` / `banned`)
is not enumerated here — it is forge's legality vocabulary, already documented in
`forge-api`'s `format_violations` field, and cortex passes it through verbatim.
   - *Alternative considered*: reference `deck-analysis-composition` and keep codex
     free of the field list. Rejected for the same self-sufficiency reason as
     `forge-api-response-shape-catchup` Decision 1: `cortex-api` exists so a
     cross-context consumer can code against cortex without reading cortex's internals.

**2. The closure requirement is not touched.**
`cortex-api`'s closure requirement already covers routes; the shape gate is now
stated platform-wide in `repository-conventions` (the widened closure clause from
`consumer-tolerance-convention`). Adding a per-capability restatement here would
duplicate a rule that now has a single authoritative source.

## Risks / Trade-offs

- **[Risk] The widened shape is still unenforced.** Nothing in CI compares cortex's
  served payload to this contract, so a third wave can still ship undocumented. →
  **Mitigation**: the platform-wide tolerance rule makes that survivable — the
  failure degrades from a production 500 to a stale spec. A response-schema validator
  is the real fix and is already recorded as a follow-up.
- **[Trade-off] Documenting `format`/`format_violations` in a cross-context contract
  exposes forge's legality vocabulary.** → Accepted: cortex already serves both to
  every consumer on every analysis read, so they are public whether the contract
  admits it or not. Describing them, including the `null`/`[]` cases, is strictly
  better than leaving consumers to discover them.

## Open Questions

(none)
