## MODIFIED Requirements

### Requirement: No other public HTTP routes at v1

`rbrain-gateway` SHALL expose exactly sixteen **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `POST /auth/register`, `POST /auth/login`, `GET /auth/oauth/google/authorize`, `GET /auth/oauth/google/callback`, `GET /auth/oauth/discord/authorize`, and `GET /auth/oauth/discord/callback` (the identity auth proxies), `POST /chat`, `GET /cards/{scryfall_id}`, `GET /cards`, `GET /rules/{number}`, `POST /decks`, `GET /decks`, `GET /decks/{id}`, `PUT /decks/{id}`, and `DELETE /decks/{id}` (the forge deck routes). Any additional public route — `POST /auth/refresh`, `POST /chat/streaming`, `GET /me`, further OAuth provider routes, password-reset routes — requires a MODIFIED delta on `gateway-api` before the route ships.

At v1, `rbrain-gateway` SHALL NOT expose any `/admin/*` route. Should one surface later (config reload, force-logout broadcast), an `/admin/*` carve-out comparable to `lexicon-api-admin-carveout` SHALL be introduced via its own OpenSpec change. Gateway SHALL reject any inbound external request whose path begins with `/admin/` regardless of underlying configuration — the `/admin/*` prefix is reserved across the platform per the `lexicon-api-admin-carveout` precedent.

#### Scenario: New public route goes through OpenSpec

- **WHEN** a contributor adds `POST /auth/refresh` or `GET /me` to gateway
- **THEN** the change SHALL include a MODIFIED requirement on this spec; CI on gateway ALONE is not enough to make the new route part of the public surface

#### Scenario: /health does not need a gateway-api requirement

- **WHEN** a contributor reads gateway-api/spec.md looking for /health
- **THEN** they SHALL find it referenced here as out-of-scope-for-this-capability and authoritative in `repository-conventions`; this spec SHALL NOT restate the /health contract

#### Scenario: External /admin/* traffic is rejected at the gateway boundary

- **WHEN** an external client requests any path matching `^/admin/`
- **THEN** gateway SHALL respond with `404 Not Found`; no proxy SHALL be attempted to any downstream

### Requirement: CORS preflight discipline

`rbrain-gateway` SHALL accept browser CORS preflight `OPTIONS` requests on every public HTTP route declared in this capability (`POST /auth/register`, `POST /auth/login`, `POST /chat`, `GET /cards`, `GET /cards/{scryfall_id}`, `GET /rules/{number}`, `POST /decks`, `GET /decks`, `GET /decks/{id}`, `PUT /decks/{id}`, `DELETE /decks/{id}`) and on the platform-wide `GET /health`.

The CORS behavior is gated by a deployment-configured allowlist of permitted browser origins. The codex contract does NOT name the env var or config key; the gateway implementation slice (`gateway-cors-policy` in `rbrain-gateway`) does.

For a preflight `OPTIONS` request whose `Origin` header value is in the deployment-configured allowlist, the gateway SHALL respond with:

- HTTP status `200 OK` (or `204 No Content`).
- `Access-Control-Allow-Origin: <verbatim origin from request>`.
- `Access-Control-Allow-Methods` listing at minimum `GET, POST, OPTIONS`.
- `Access-Control-Allow-Headers` listing at minimum `authorization, content-type`.

For a preflight request whose `Origin` is NOT in the allowlist, the gateway SHALL NOT emit any `Access-Control-Allow-*` header in the response; the browser then enforces the rejection by failing the subsequent fetch.

When the deployment-configured allowlist is empty (the default, no opt-in), the gateway SHALL NOT emit any `Access-Control-Allow-*` header for any origin on any route. The gateway is browser-incompatible by default; deployments enable browser access by setting the allowlist.

The CORS layer SHALL short-circuit `OPTIONS` requests before they reach the Bearer-JWT middleware: preflight is not an auth event. Subsequent non-preflight requests on the protected group continue to go through `jwt_middleware` as specified by the existing Requirement "rbrain-gateway gates protected routes behind a Bearer JWT".

The CORS layer SHALL apply uniformly to all public routes — there is no per-route allowlist; a single deployment-level list covers `/auth/*`, `/health`, `/chat`, `/cards`, `/cards/*`, `/rules/*`, and `/decks/*`.

#### Scenario: Allowlisted origin preflight on /auth/register

- **WHEN** a browser at origin `http://localhost:3000` (which is in the deployment allowlist) sends `OPTIONS /auth/register` with headers `Origin: http://localhost:3000`, `Access-Control-Request-Method: POST`, `Access-Control-Request-Headers: content-type`
- **THEN** the gateway SHALL respond with `200 OK` (or `204 No Content`); the response headers SHALL include `Access-Control-Allow-Origin: http://localhost:3000`, `Access-Control-Allow-Methods` containing `POST` and `OPTIONS`, and `Access-Control-Allow-Headers` containing `content-type`

#### Scenario: Preflight on a deck mutation route is accepted

- **WHEN** an allowlisted browser sends `OPTIONS /decks/{id}` with `Access-Control-Request-Method: PUT` (or `DELETE`)
- **THEN** the gateway SHALL respond `200 OK` (or `204`) with `Access-Control-Allow-Origin` set to the request origin and `Access-Control-Allow-Methods` containing the requested method and `OPTIONS`; the preflight SHALL NOT invoke the Bearer-JWT middleware

#### Scenario: Non-allowlisted origin gets no CORS headers

- **WHEN** a browser at origin `https://evil.example` (NOT in the allowlist) sends a preflight `OPTIONS /chat` request
- **THEN** the response SHALL NOT include any `Access-Control-Allow-Origin` header; the browser SHALL fail the subsequent fetch

#### Scenario: Empty allowlist disables CORS for every origin

- **WHEN** the deployment has no allowlist configured and any browser sends `OPTIONS /chat` with any `Origin`
- **THEN** the response SHALL NOT include any `Access-Control-Allow-*` header on any route

#### Scenario: Preflight does not invoke JWT middleware

- **WHEN** an allowlisted browser sends `OPTIONS /chat` without an `Authorization` header
- **THEN** the gateway SHALL respond `200 OK` (or `204`) with CORS headers; it SHALL NOT respond `401 {"error":"invalid token"}` — preflight is not an auth event
