# Proposal — forge-api-response-schema

## Why

`forge-api`'s shape closure ("the same gate SHALL apply to the **shape** of the existing eight
routes") is enforced today only by humans reading `spec.md` against forge's code. A response-shape
drift — a field renamed, a route added, a query parameter dropped — is caught, if at all, by a
reviewer, not by CI. Every other closed surface already follows the `format-catalog` pattern: a
machine-readable source compared to the implementing repo in CI. `forge-api` is the last one
without it.

This change is the codex half of that gate: the schema plus a validator proving the schema is
well-formed, still describes exactly the closed eight, and that forge's Axum router matches it as a
route set. Runtime shape-checking of the stateless routes is opt-in against a live forge, keeping
the unit gate free of a running-service dependency.

## What Changes

- `openspec/specs/forge-api/schema.yaml` — the machine-readable projection of `forge-api/spec.md`:
  a `components` block (deck entry, parse error, format violation, parsed deck, stored deck, deck
  summary, analysis, card fact, error) and a `routes` block carrying each route's method, path,
  accepted request-body fields and per-status response shapes. A documented field grammar
  (`type` plus `nullable`, `required`, `enum`, `items`, `fields`, `additional`) keeps the file
  checkable against itself.
- `scripts/validate-response-shapes.sh` — the validator, mirroring the `format-catalog`
  mechanism: self mode (schema well-formed, route set exactly the closed eight, the spec still
  declares "exactly eight HTTP routes"), sibling mode (forge's Axum router equals the schema's
  route set, keyed on the repo's `OWNERSHIP.yaml` context), and an opt-in runtime smoke against a
  live forge (`FORGE_URL`) type-checking `GET /health`, `POST /decks/parse` and
  `POST /decks/analyze` response bodies against the schema.
- **BREAKING**: none. No route, response field or request body changes; the schema describes the
  contract forge already implements. This is pure enforcement machinery, additive to the codex
  repo.

## Capabilities

### Modified Capabilities

- `forge-api`: gains a requirement that the response shapes be machine-checkable — the schema as
  the single machine-readable projection, and the CI obligations that compare the schema to the
  spec and (in sibling mode, once forge wires it) to forge's router.

## Impact

- `rbrain-codex`: new `schema.yaml` + `scripts/validate-response-shapes.sh` + one CI step
  (`Validate response shapes`); `forge-api/spec.md` gains the machine-readability requirement.
- `rbrain-forge`: no OpenSpec change of its own now. It gains the sibling-mode CI step and its
  router becomes the thing the validator checks — a chore commit referencing this change,
  following the `format-catalog` precedent (`validate-formats.sh` sibling wiring).
- `rbrain-cortex`, `rbrain-app`, other repos: none. Consumers' mirrors are already governed by
  `forge-payload-tolerance`; this gate closes the producer side.
