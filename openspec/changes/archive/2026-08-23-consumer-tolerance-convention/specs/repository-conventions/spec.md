# repository-conventions — Delta

## MODIFIED Requirements

### Requirement: <context>-api capabilities include a route-closure clause

Every codex capability whose name matches the `<context>-api` pattern (`lexicon-api`, `cortex-api`, and any future `gateway-api` / `oracle-api` / `forge-api` / `identity-api` / `chronicle-api`) SHALL include at least one requirement whose body enumerates the closed set of public HTTP routes for that bounded context and states that adding any further public route requires a MODIFIED delta on that capability.

The closure-clause requirement SHALL:

- Reference `repository-conventions` as the authoritative source for `GET /health` rather than restating the `/health` contract.
- Explicitly list every public route the capability ratifies (e.g., `POST /chat` for cortex, `GET /cards/{scryfall_id}` + `GET /cards` for lexicon).
- State that any route addition requires a MODIFIED delta on the same capability before the route ships.
- Optionally carve out a `/admin/*` prefix (or any other operator-only prefix) if the sibling has admin endpoints; this MAY live in a separate carve-out change (see `lexicon-api-admin-carveout` precedent).

The same gate SHALL apply to the **shape** of the existing routes, not only to their number. A change that adds, removes, or renames a field in any response payload, adds or removes an accepted request-body field, or adds or removes an accepted query parameter requires a MODIFIED delta on that capability before it ships — even when the route set is untouched. A widening that leaves every existing field in place is still a contract change, because a consumer validating the payload against this document is entitled to have read a true description of it.

Capabilities that do NOT match the `<context>-api` pattern (e.g., `bounded-contexts`, `data-stores`, `cortex-bootstrap`) are out of scope — they are not public HTTP contracts.

#### Scenario: A new sibling's <context>-api capability ships without the closure clause

- **WHEN** a contributor proposes a new `oracle-api` capability that lists only the routes it ratifies without a closure clause
- **THEN** the OpenSpec change SHALL be rejected at review; the missing requirement is a violation of this convention

#### Scenario: lexicon-api conforms

- **WHEN** a contributor reads `openspec/specs/lexicon-api/spec.md`
- **THEN** they SHALL find the requirement "No other HTTP routes at v1" enumerating `GET /health`, `GET /cards/{scryfall_id}`, and `GET /cards`; additions require a MODIFIED delta on `lexicon-api`

#### Scenario: cortex-api conforms

- **WHEN** a contributor reads `openspec/specs/cortex-api/spec.md`
- **THEN** they SHALL find the requirement "No other public HTTP routes at v1" enumerating `GET /health` and `POST /chat`; additions require a MODIFIED delta on `cortex-api`

#### Scenario: A response-shape widening goes through OpenSpec

- **WHEN** a contributor adds a field to a `<context>-api` response payload, or a new accepted field to a request body, without adding any route
- **THEN** the change SHALL include a MODIFIED requirement on that capability's spec before it ships; documenting the field only in the sibling's own capability spec is not enough, because the cross-context consumers read the `<context>-api` document

#### Scenario: An admin-prefix carve-out coexists with the closure clause

- **WHEN** a sibling adds `/admin/*` operator-only endpoints (mirroring `lexicon-api-admin-carveout`)
- **THEN** the carve-out SHALL live either inside the same closure-clause requirement or as a sibling requirement on the same `<context>-api` capability; in both cases the closure clause SHALL still hold for the non-`/admin/*` public routes

## ADDED Requirements

### Requirement: Consumer tolerance of additive response fields

An additive change to a `<context>-api` response payload SHALL be documented in that capability's contract before it ships, **and** a consumer of that response SHALL ignore fields it does not recognise rather than rejecting the payload. Both obligations hold at once: neither one alone is sufficient, and each covers the other's failure mode.

The producer obligation is the delta gate stated by the closure requirement above. The consumer obligation constrains how every consumer of a `<context>-api` payload builds its models of it: a deserialiser configured to reject unknown fields turns a backwards-compatible widening on the producer's side into a runtime failure on the consumer's side, on a route that was working. Consumers SHALL NOT be configured that way against a `<context>-api` payload.

A consumer that wants eager detection of contract drift SHALL obtain it from a contract test comparing a recorded payload against its expected field set, where a mismatch fails that consumer's CI — not from strict rejection in the model that serves production traffic.

This requirement is stated for the platform's `<context>-api` contracts as a whole. A per-capability statement (e.g., `forge-api`'s "Additive response fields and consumer tolerance") SHALL reference this requirement as the authoritative source rather than restating it.

#### Scenario: A sibling grows a response field

- **WHEN** a sibling adds a field to a `<context>-api` response payload, documented by a MODIFIED delta on that capability's spec
- **THEN** a consumer deserialising that payload SHALL continue to operate on the fields it knows, ignoring the new one, without a lockstep release

#### Scenario: A consumer rejects an unknown field

- **WHEN** a consumer's `<context>-api` payload model is configured to reject unrecognised fields
- **THEN** that configuration SHALL be treated as a defect in the consumer, remedied by ignoring unknown fields and moving drift detection into a contract test

#### Scenario: An undocumented widening is still a contract violation

- **WHEN** a sibling ships a new response field without a MODIFIED delta on its `<context>-api` spec, and every consumer tolerates it
- **THEN** the absence of a runtime failure SHALL NOT make the omission acceptable; the delta is still owed, and the contract is stale until it lands
