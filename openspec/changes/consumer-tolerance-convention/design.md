## Context

`forge-api-response-shape-catchup` (2026-08-17) closed the rule gap for forge:
its closure clause now gates response shapes, request bodies, and query
parameters, and its requirement "Additive response fields and consumer
tolerance" states the compatibility posture — a producer SHALL document an
additive field via a delta, and a consumer SHALL ignore fields it does not
recognise. That change explicitly scoped itself to forge and recorded the
promotion as a follow-up: "promoting the consumer-tolerance requirement to
`repository-conventions` across the six other `<context>-api` capabilities".

The gap this change closes is the same one forge had, at platform scale.
`repository-conventions`'s closure clause gates on routes alone — a
response-shape widening satisfies it by saying nothing — and the convention
has no consumer-tolerance requirement at all. The six other `<context>-api`
capabilities (`lexicon-api`, `oracle-api`, `identity-api`, `gateway-api`,
`chronicle-api`, `cortex-api`) have the exposure forge had, and nothing
protects them.

## Goals / Non-Goals

**Goals:**
- Make the route-closure convention gate response shapes and request bodies,
  not only paths — the platform-wide version of what forge-api did locally.
- State the consumer-tolerance posture once, at the platform level, so every
  `<context>-api` capability inherits it and future capabilities get it by
  construction.
- Keep `forge-api` self-sufficient for its own consumers while pointing at the
  authoritative source.

**Non-Goals:**
- No behaviour change in any sibling. This is a spec-only change.
- No audit of the six other capabilities' consumer mirrors in this change.
  The rule is now stated; each consumer's `extra="forbid"` → `extra="ignore"`
  move is a per-repo change of its own, exactly as cortex's was for forge.
- No CI validator for response-shape drift. Still blocked on a
  machine-readable response schema (see `forge-api-response-shape-catchup`
  design.md Open Questions).

## Decisions

**1. The rule is promoted to `repository-conventions`, not duplicated into
every `<context>-api` capability.**
The health-endpoint convention is the precedent: the platform convention is
the authoritative source, and per-sibling capabilities reference it rather
than restating it. Six copies of the same paragraph would drift apart; one
statement plus per-capability pointers does not. The closure clause is widened
in place (one place to look for "what needs a delta before it ships"), exactly
as forge-api widened its own.

**2. `forge-api` keeps its local statement as a pointer.**
The requirement "Additive response fields and consumer tolerance" stays in
forge-api — its consumers should not have to read two documents — but its
closing note now references `repository-conventions` as the authoritative
source and drops the "deliberately not in its scope" sentence. The rule is no
longer forge-specific; the local statement is the forge-specific instance of
it.

**3. The consumer half ships as a platform rule, not as per-repo edits.**
The rule constrains how every consumer of a `<context>-api` payload builds its
models: a deserialiser configured to reject unknown fields turns a
backwards-compatible widening into a runtime failure. Stating that as a
convention makes the posture reviewable at contract time; the actual
`extra="ignore"` edits in each consumer repo remain per-repo changes with
their own gates, as cortex's was.

## Risks / Trade-offs

- **[Risk] The widened rule is still unenforced.** Nothing in CI compares a
  sibling's served payload to its `<context>-api` contract, so a widening can
  still ship undocumented. → **Mitigation**: the consumer half is what makes
  that survivable — the failure degrades from a production 500 to a stale
  spec. A response-schema validator remains the real fix and is still a
  recorded follow-up.
- **[Trade-off] Promoting the rule does not fix existing consumer
  strictness.** `rbrain-app`'s LLM mirrors keep `extra="forbid"` (a recorded
  open question), and other consumers may too. → Accepted: the convention
  states the posture; each consumer's remediation is a per-repo change with
  its own audit.

## Open Questions

- Should the six other `<context>-api` capabilities each gain a local
  tolerance statement pointing at `repository-conventions`, mirroring
  forge-api's? This change promotes the rule and updates forge-api; the other
  six are left as-is because their contracts do not yet state the rule
  locally. A follow-up could add the pointer to each — or leave them to
  inherit it, since the convention is the authoritative source either way.
