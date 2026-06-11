## MODIFIED Requirements

### Requirement: No other HTTP routes at v1

`rbrain-lexicon` SHALL expose exactly two **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`) and `GET /cards/{scryfall_id}` (defined here). Any additional public route — list endpoints, search endpoints, batch endpoints, or new `/cards/*` subpaths — requires a MODIFIED delta on `lexicon-api` before the route ships.

Routes under the reserved prefix `/admin/*` are **operator/platform-internal** and SHALL NOT count toward this constraint. Their existence does NOT require a MODIFIED on `lexicon-api`. The shape and behavior of each `/admin/*` endpoint live in lexicon's own capability specs (e.g. `scryfall-sync`'s `/admin/sync` lives in `rbrain-lexicon`'s `openspec/specs/scryfall-sync/spec.md`).

`/admin/*` routes SHALL NOT be reachable through `rbrain-gateway` once gateway routing ships; gateway's ingress rules MUST reject any external request whose path begins with `/admin/`. Until gateway exists, lexicon's internal-only status (per `service-topology`'s sync graph) is the implicit protection.

#### Scenario: New public endpoint goes through OpenSpec

- **WHEN** a contributor adds `GET /cards/by-name/{name}` to lexicon
- **THEN** the change SHALL include a MODIFIED requirement on this spec; CI on lexicon ALONE is not enough to make the new endpoint part of the public surface

#### Scenario: Admin endpoint does not need a codex spec change

- **WHEN** a contributor adds `POST /admin/sync` (or any other `/admin/*` route) to lexicon
- **THEN** the change SHALL NOT require a MODIFIED on `lexicon-api`; the endpoint's behavior is captured in lexicon's own capability spec, and gateway's routing rules ensure the endpoint is not reachable from outside the cluster

#### Scenario: Gateway rejects external admin traffic

- **WHEN** `rbrain-gateway` (once shipped) receives an external request with a path matching `^/admin/`
- **THEN** the gateway SHALL respond with HTTP 404 (or another suitable status) without forwarding the request to lexicon; the gateway-side routing rules SHALL enforce this regardless of method
