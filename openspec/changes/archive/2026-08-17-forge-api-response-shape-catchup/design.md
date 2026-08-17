## Context

The drift is one-directional and entirely in the response shape — the route set never moved.
Verified against `rbrain-forge` at `33b6dc0` (main):

| Element | `forge-api` says | forge serves | Documented in |
|---|---|---|---|
| `POST`/`PUT`/`GET /decks/{id}` response | 8 fields | 12 fields (`+format`, `+format_violations`, `+status`, `+version`) | `forge-deck-persistence` only |
| `POST /decks` body | `decklist`, `name?` | `+format?`, `+status?` | `forge-deck-persistence` only |
| `PUT /decks/{id}` body | `name?`, `decklist?` | `+format?`, `+status?` | `forge-deck-persistence` only |
| `GET /decks/{id}` query | none | `?version=N` | `forge-deck-persistence` only |
| `GET /decks` (list) response | 4 fields | 4 fields | in sync |
| Route set | eight paths | eight paths | in sync |

`GET /decks` is worth noting as the control case: `DeckSummary` was never widened, so the drift is
specific to the full-deck payload rather than a general laxity about this contract.

Two facts shape the decisions below.

1. **The rule that was supposed to catch this gates on routes.** `forge-api`'s closure requirement
   says "any additional route … requires a MODIFIED delta", and `AGENTS.md` says "when a sibling
   ships a new public **endpoint**". A response-shape widening satisfies both by saying nothing.
   Yesterday's `deck-draft-versions` design reasoned explicitly from this — "staying inside the
   existing eight routes … avoids touching `rbrain-codex` at all for this change" — and was right
   about the rule as written.

2. **The consumer turns a benign widening into an outage.** `rbrain-cortex/app/forge/types.py`
   declares `StoredDeck` with `model_config = ConfigDict(extra="forbid")`. Pydantic then *rejects*
   a payload carrying a field the model does not declare. Each of forge's three waves therefore
   required a lockstep cortex edit or would have 500'd a live route, and the deploy order became
   load-bearing (cortex first, or atomically). That is a self-inflicted coupling: forge's additive
   change is backwards-compatible by construction, and only the consumer's strictness makes it not.

## Goals / Non-Goals

**Goals:**
- Make `forge-api` describe the payload forge actually serves, so the next delta is written against
  a true baseline rather than a three-wave-old one.
- Close the rule gap that let three waves through: gate response shapes and request bodies, not only
  paths.
- State the compatibility posture once, so the `errors` widening that follows this change — and the
  ones after it — cost a delta rather than a cross-repo lockstep.

**Non-Goals:**
- No behaviour change in forge. Every field documented here already ships.
- No generalisation to the other five `<context>-api` capabilities in this change (Decision 4).
- No enumeration of the accepted `format` values in codex (Decision 1).
- No CI validator for response-shape drift. Worth wanting, needs a machine-readable response schema
  that this contract does not have; noted as a follow-up rather than half-built here.

## Decisions

**1. The contract enumerates the sixteen accepted `format` values, rather than pointing elsewhere for
them.**
Where the values live today was checked rather than assumed, and the answer decided this: **no codex
capability enumerates them at all.** The list appears in `rbrain-forge`'s own
`forge-deck-persistence` spec, and its upstream origin is the whitelist in `rbrain-lexicon`'s
`lexicon-events`. Both are sibling-local specs.

Pointing at either would defeat the purpose of this file. `forge-api` exists so a cross-context
consumer can code against forge without reading forge's internals; a contract that says "one of the
values enumerated in the producer's private spec" sends the reader into the very repository the
contract was meant to abstract. Self-sufficiency wins over non-duplication here.

The duplication risk is real and is named rather than waved away: the list already moved once
(`forge-legality-format-expansion`, 2026-07-12, five days after the last `forge-api` edit). Two
things contain it. The widened closure requirement now makes any change to the accepted value set a
delta-gated change, so an expansion cannot silently desynchronise the two lists the way the last one
did. And the proper fix — the whitelist as a single platform-level source in codex, the way
`catalog.yaml` and `sync-graph.yaml` already are, consumed by lexicon and forge alike — is recorded
as a follow-up. That is a change of its own: it needs a support (new capability or YAML source), a
validator, and an audit of both consumers.
   - *Alternative considered*: reference `forge-deck-persistence` and keep codex free of the list.
     Rejected for the self-sufficiency reason above — and it would have been a reference to a
     document a cortex or app developer has no reason to have open.

**2. The closure requirement is widened to response shapes and request bodies, not replaced.**
The route-closure clause keeps its current force; the delta adds response payloads and request
bodies to what it governs. Widening rather than adding a second requirement keeps one place to look
for "what needs a delta before it ships", which is the property that failed here — the rule existed
and was read, it simply did not cover this.

**3. Both halves of the compatibility posture ship, and the consumer half ships as its own change.**
The new requirement states that forge SHALL document an additive field via a delta *and* that
consumers SHALL ignore fields they do not recognise.
   - *Why both.* The rule alone is what we had, and it held zero times out of three. Tolerance alone
     would keep the runtime safe while letting the contract rot silently — the state this change is
     cleaning up. Each half covers the other's failure mode: tolerance makes a missed delta a
     documentation debt instead of an outage, and the delta rule keeps tolerance from becoming a
     licence to stop writing things down.
   - *Why not in this change.* The cortex edit (`extra="forbid"` → `extra="ignore"` on the forge
     mirror types) is code in another repository, with its own gates and its own tests. It ships as
     the next slice, before forge emits `errors`. This change is spec-only and independently
     mergeable.
   - *Alternative considered*: keep `extra="forbid"` and accept the lockstep discipline, on the
     grounds that strictness catches contract drift early. Rejected — it catches drift at runtime,
     in production, on a live route, which is the worst available place to catch it. Drift detection
     belongs in a contract test against a recorded forge payload; a production DTO's job is to
     survive a producer that grew a field. Recorded as a cortex-side follow-up so the detection is
     not simply lost.

**4. Scope stays on `forge-api`; generalisation is a named follow-up.**
The tolerance requirement is phrased for forge's consumers specifically, not as a platform-wide law,
even though `lexicon-api`, `oracle-api`, `identity-api`, `gateway-api`, `chronicle-api` and
`cortex-api` all have the same exposure. Promoting it to `repository-conventions` means auditing six
contracts and every consumer mirror of each — a change of its own, not a paragraph appended to this
one. Stating it locally now is honest about its reach and does not block the promotion later.

## Risks / Trade-offs

- **[Risk] The widened rule is still unenforced.** Nothing in CI compares forge's served payload to
  this contract, so a fourth wave can still ship undocumented. → **Mitigation**: Decision 3's
  consumer half is what makes that survivable — the failure degrades from a production 500 to a
  stale spec. A response-schema validator is the real fix and is recorded as a follow-up, not
  pretended at here.
- **[Trade-off] `extra="ignore"` in cortex loses eager drift detection at the validation boundary.**
  → Accepted, with the compensating follow-up in Decision 3: a contract test asserting the expected
  field set against a recorded payload, where a mismatch fails CI instead of a user's request.
- **[Trade-off] Documenting `version` in a cross-context contract exposes an internal-ish concept.**
  `version` is meaningful only for decks that went through the draft path and is `null` otherwise.
  → Accepted: forge already serves it to every consumer on every deck read, so it is public whether
  the contract admits it or not. Describing it, including the `null` case, is strictly better than
  leaving consumers to discover it.

## Open Questions

- Should a `validate-response-shapes.sh` validator be built, and against what machine-readable
  source? Would require forge to publish a schema (or codex to carry one per route). Out of scope
  here; the answer determines whether the widened rule ever becomes enforceable rather than merely
  written.
