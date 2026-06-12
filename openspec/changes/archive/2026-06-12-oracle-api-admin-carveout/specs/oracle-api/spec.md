## MODIFIED Requirements

### Requirement: No other public HTTP routes at v1

`rbrain-oracle` SHALL expose exactly two **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`) and `GET /rules/{number}` (defined here). Any additional public route — listing endpoints, batch endpoints, semantic search endpoints, glossary endpoints, ruling endpoints, or new `/rules/*` subpaths — requires a MODIFIED delta on `oracle-api` before the route ships.

Routes under the reserved prefix `/admin/*` are **operator/platform-internal** and SHALL NOT count toward this constraint. Their existence does NOT require a MODIFIED on `oracle-api`. The shape and behavior of each `/admin/*` endpoint live in oracle's own capability specs (e.g. `comprehensive-rules-sync`'s `/admin/sync` lives in `rbrain-oracle`'s `openspec/specs/comprehensive-rules-sync/spec.md`).

`/admin/*` routes SHALL NOT be reachable through `rbrain-gateway` once gateway routing ships; gateway's ingress rules MUST reject any external request whose path begins with `/admin/`. Until gateway exists, oracle's internal-only status (per `service-topology`'s sync graph) is the implicit protection.

#### Scenario: New public endpoint goes through OpenSpec

- **WHEN** a contributor adds `POST /rules/semantic-search` or `GET /glossary/{term}` to oracle
- **THEN** the change SHALL include a MODIFIED requirement on this spec; CI on oracle ALONE is not enough to make the new endpoint part of the public surface

#### Scenario: /health does not need an oracle-api requirement

- **WHEN** a contributor reads oracle-api/spec.md looking for `/health`
- **THEN** they SHALL find it referenced here as out-of-scope-for-this-capability and authoritative in `repository-conventions`; this spec SHALL NOT restate the `/health` contract

#### Scenario: Admin endpoint does not need a codex spec change

- **WHEN** a contributor adds `POST /admin/sync` (or any other `/admin/*` route) to oracle
- **THEN** the route SHALL be permitted without a MODIFIED on this spec; the per-endpoint contract SHALL live in the consuming oracle capability spec

#### Scenario: Gateway rejects external admin traffic

- **WHEN** `rbrain-gateway` (once shipped) receives an external request with a path matching `^/admin/`
- **THEN** gateway SHALL reject the request before it reaches oracle; no `/admin/*` route SHALL be reachable from public ingress
