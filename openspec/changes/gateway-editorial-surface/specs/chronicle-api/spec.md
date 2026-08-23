## MODIFIED Requirements

### Requirement: No other public HTTP routes at v1

`rbrain-chronicle` SHALL expose exactly three **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `GET /articles`, and `GET /articles/{slug}` (defined here). Any additional public route — article comments, category indexes, RSS/Atom feeds, search — requires a MODIFIED delta on `chronicle-api` before the route ships.

Routes under the reserved prefix `/admin/*` are **operator/platform-internal** and SHALL NOT count toward this constraint. Editorial authoring (draft create/update, publish, delete) lives under `/admin/articles/*`; its shape and behavior are specified by `rbrain-chronicle`'s own authoring capability, not here, exactly as `scryfall-sync`'s `/admin/sync` lives in `rbrain-lexicon`. Per the `lexicon-api-admin-carveout` precedent and `gateway-api`, `/admin/*` PATHS SHALL NOT be reachable through `rbrain-gateway`: gateway rejects any external request whose path begins with `/admin/`. The gateway MAY expose its own authenticated, allowlist-gated editorial surface (`/editorial/*`, per `gateway-api`) that rewrites onto this internal admin surface — the trust decision then lives at the gateway boundary, and chronicle's admin routes remain unreachable by their own path.

#### Scenario: New public route goes through OpenSpec

- **WHEN** a contributor adds `GET /feed.xml` or `GET /categories` to chronicle
- **THEN** the change SHALL include a MODIFIED requirement on this spec before the route ships; CI on chronicle alone is not enough to make it part of the public surface

#### Scenario: Authoring routes are operator-internal, not public

- **WHEN** a contributor adds `POST /admin/articles` or `POST /admin/articles/{id}/publish` to chronicle
- **THEN** that route SHALL live under `/admin/*`, SHALL NOT count toward this public-route closure, and SHALL NOT be reachable through gateway by its own `/admin/*` path — only, where `gateway-api` declares it, through the gateway's authenticated `/editorial/*` rewrite

#### Scenario: /health does not need a chronicle-api requirement

- **WHEN** a contributor reads chronicle-api/spec.md looking for /health
- **THEN** they SHALL find it referenced here as out-of-scope-for-this-capability and authoritative in `repository-conventions`; this spec SHALL NOT restate the /health contract

