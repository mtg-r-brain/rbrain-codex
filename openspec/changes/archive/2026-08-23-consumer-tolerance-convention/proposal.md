# Proposal — consumer-tolerance convention

## Why

`forge-api` carries the platform's only statement of the consumer-tolerance
rule: an additive response-field change must be documented in the contract
before it ships, **and** a consumer must ignore fields it does not recognise
rather than rejecting the payload. That rule exists because forge's three
response widenings each required a lockstep cortex edit — a self-inflicted
coupling where a backwards-compatible producer change became a runtime 500 on
the consumer's side.

The rule is stated for forge's consumers only. `repository-conventions` — the
platform-wide contract every `<context>-api` capability inherits — has nothing
on consumer tolerance, and its closure clause gates on routes alone, not on
response shapes. The other six `<context>-api` capabilities (`lexicon-api`,
`oracle-api`, `identity-api`, `gateway-api`, `chronicle-api`, `cortex-api`)
have the same exposure forge had, and nothing protects them.

The `forge-api-response-shape-catchup` change (2026-08-17) recorded this as a
named follow-up: "promoting the consumer-tolerance requirement to
`repository-conventions` across the six other `<context>-api` capabilities".

## What Changes

- `repository-conventions`'s closure clause is widened to response shapes and
  request bodies, not only routes: a change that adds, removes, or renames a
  field in any response payload, adds or removes an accepted request-body
  field, or adds or removes an accepted query parameter requires a MODIFIED
  delta on that capability before it ships — even when the route set is
  untouched.
- `repository-conventions` gains a requirement "Consumer tolerance of additive
  response fields": an additive change to a `<context>-api` response payload
  SHALL be documented in that capability's contract before it ships, **and** a
  consumer of that response SHALL ignore fields it does not recognise rather
  than rejecting the payload. Both obligations hold at once. A consumer that
  wants eager drift detection SHALL obtain it from a contract test comparing a
  recorded payload against its expected field set, not from strict rejection
  in the model that serves production traffic.
- `forge-api`'s tolerance requirement is updated to reference
  `repository-conventions` as the authoritative source and to drop its
  "deliberately not in its scope" note — the rule is now platform-wide, and
  forge-api's local statement becomes a pointer rather than a one-off.

## Context

`repository-conventions` is the platform-wide contract every `rbrain-*` repo
inherits: mandatory root files, OWNERSHIP.yaml schema, AGENTS.md baseline,
health-endpoint convention, route-closure clause, PORT binding, archive
staging. Its closure clause (requirement "<context>-api capabilities include a
route-closure clause") enumerates the closed set of public routes per
capability and states that adding any further route requires a MODIFIED delta.
It does not cover response shapes, and it has no consumer-tolerance
requirement.

`forge-api`'s closure clause was already widened to shapes by
`forge-api-response-shape-catchup`, and its requirement "Additive response
fields and consumer tolerance" states the full rule — but scoped to forge's
consumers, with the note that extending it to the other `<context>-api`
contracts is deliberately out of its scope.

## Decision: the rule is promoted to the platform convention, forge-api points at it

The rule belongs in `repository-conventions` because it is a property of every
`<context>-api` contract, not of forge. Promoting it there — the way the
health-endpoint convention was promoted — gives the six other capabilities the
protection forge got, and gives future capabilities the rule by inheritance
rather than by rediscovery.

`forge-api` keeps its local statement but as a pointer: the requirement
references `repository-conventions` as the authoritative source and drops the
"not in its scope" note. This mirrors the health-endpoint pattern, where
per-sibling capabilities reference the convention rather than restating it.

## Options considered

- **Leave the rule in forge-api only** (status quo): the six other
  capabilities stay unprotected, and the next widening in any of them
  re-learns the forge lesson at runtime. Rejected: the follow-up exists
  precisely because this is a platform-wide property.
- **Duplicate the full rule into every `<context>-api` capability**: maximal
  locality, but six copies of the same paragraph that drift apart. Rejected:
  the health-endpoint precedent shows the platform convention is the right
  home, with per-capability pointers.
- **Promote to repository-conventions and delete forge-api's statement**:
  forge-api's consumers would have to read two documents to learn the rule.
  Rejected: keep the local statement as a pointer so forge-api stays
  self-sufficient for its own consumers.

## Provenance rule

The consumer-tolerance requirement constrains how every consumer of a
`<context>-api` payload builds its models: a deserialiser configured to reject
unknown fields turns a backwards-compatible widening on the producer's side
into a runtime failure on the consumer's side. Consumers SHALL NOT be
configured that way against a `<context>-api` payload. Drift detection belongs
in a contract test against a recorded payload, where a mismatch fails that
consumer's CI — not in the model that serves production traffic.
