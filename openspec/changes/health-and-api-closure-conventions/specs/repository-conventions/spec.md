## ADDED Requirements

### Requirement: Health endpoint convention

Every `rbrain-*` sibling whose `OWNERSHIP.runtime` is NOT `none` SHALL expose an HTTP endpoint at `GET /health`. The endpoint SHALL:

- Respond with status `200 OK`.
- Respond with `Content-Type: application/json`.
- Return a JSON object with exactly two string fields, in any key order:
  - `status`: the literal string `"ok"`.
  - `context`: the bounded context name matching `OWNERSHIP.yaml.context`.
- Not require any authentication.
- Not accept any path parameters or query parameters; any extra path segment or query string SHALL be ignored or SHALL cause the endpoint to return its standard 200 response (per-runtime routing defaults are acceptable).

`rbrain-codex` and `rbrain-deploy` (both declared `runtime: none`) are explicitly out of scope and SHALL NOT need to implement this requirement.

Per-sibling `<context>-api` capabilities SHALL reference this requirement when carving `/health` out of their public route closure clause (see "<context>-api capabilities include a route-closure clause" below) rather than restating the `/health` contract.

#### Scenario: Cortex /health smoke test

- **WHEN** an operator issues `GET http://cortex-host/health`
- **THEN** the response SHALL carry status `200`, body `{"status":"ok","context":"cortex"}`; no authentication header SHALL be required

#### Scenario: Lexicon /health smoke test

- **WHEN** an operator issues `GET http://lexicon-host/health`
- **THEN** the response SHALL carry status `200`, body `{"status":"ok","context":"lexicon"}`

#### Scenario: codex and deploy are out of scope

- **WHEN** a contributor checks `rbrain-codex` or `rbrain-deploy` for a `/health` endpoint
- **THEN** they SHALL find no such endpoint; this is conformant because both repos declare `runtime: none` in their OWNERSHIP.yaml

#### Scenario: Extra fields in the response body are forbidden

- **WHEN** the body of `GET /health` is parsed
- **THEN** it SHALL NOT carry any field outside `status` and `context`; adding a third field (e.g., `version`, `git_sha`, `uptime_seconds`) requires a MODIFIED delta on this requirement

### Requirement: <context>-api capabilities include a route-closure clause

Every codex capability whose name matches the `<context>-api` pattern (`lexicon-api`, `cortex-api`, and any future `gateway-api` / `oracle-api` / `forge-api` / `identity-api` / `chronicle-api`) SHALL include at least one requirement whose body enumerates the closed set of public HTTP routes for that bounded context and states that adding any further public route requires a MODIFIED delta on that capability.

The closure-clause requirement SHALL:

- Reference `repository-conventions` as the authoritative source for `GET /health` rather than restating the `/health` contract.
- Explicitly list every public route the capability ratifies (e.g., `POST /chat` for cortex, `GET /cards/{scryfall_id}` + `GET /cards` for lexicon).
- State that any route addition requires a MODIFIED delta on the same capability before the route ships.
- Optionally carve out a `/admin/*` prefix (or any other operator-only prefix) if the sibling has admin endpoints; this MAY live in a separate carve-out change (see `lexicon-api-admin-carveout` precedent).

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

#### Scenario: An admin-prefix carve-out coexists with the closure clause

- **WHEN** a sibling adds `/admin/*` operator-only endpoints (mirroring `lexicon-api-admin-carveout`)
- **THEN** the carve-out SHALL live either inside the same closure-clause requirement or as a sibling requirement on the same `<context>-api` capability; in both cases the closure clause SHALL still hold for the non-`/admin/*` public routes
