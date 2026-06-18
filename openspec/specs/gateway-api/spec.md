# gateway-api Specification

## Purpose
TBD - created by archiving change gateway-api. Update Purpose after archive.
## Requirements
### Requirement: rbrain-gateway proxies the identity auth routes unauthenticated

`rbrain-gateway` SHALL expose `POST /auth/register`, `POST /auth/login`, `GET /auth/oauth/google/authorize`, `GET /auth/oauth/google/callback`, `GET /auth/oauth/discord/authorize`, and `GET /auth/oauth/discord/callback` as **unauthenticated** reverse proxies to `rbrain-identity`. The request body, request headers (except `Host` and `Authorization`), HTTP method, and response body/status/headers SHALL pass through unchanged.

These routes SHALL NOT require an Authorization header. Any Authorization header on these routes SHALL be stripped before forwarding.

Because the OAuth routes make `rbrain-identity` reply with redirects and cookies, the gateway SHALL **relay and not follow** upstream `3xx` responses: the response status, the `Location` header, and any `Set-Cookie` header(s) SHALL be re-emitted to the client verbatim, and the gateway SHALL NOT itself follow the `Location`. (The state cookie thus round-trips between the browser and identity through the gateway.)

#### Scenario: register flows through gateway to identity

- **WHEN** a client posts `POST /auth/register` against gateway with a valid identity-api request body
- **THEN** gateway SHALL forward the request to `${IDENTITY_URL}/auth/register`; the response status, body, and content-type SHALL be re-emitted verbatim from identity

#### Scenario: login flows through gateway to identity

- **WHEN** a client posts `POST /auth/login`
- **THEN** gateway SHALL forward to `${IDENTITY_URL}/auth/login`; identity's `200 + JWT envelope` or `401 + invalid-credentials` response SHALL flow back verbatim

#### Scenario: Authorization on /auth/* is stripped

- **WHEN** a client posts `POST /auth/login` with `Authorization: Bearer <something>`
- **THEN** gateway SHALL strip the Authorization header before forwarding; identity SHALL NOT see it

#### Scenario: OAuth authorize redirect is relayed, not followed

- **WHEN** a browser requests an OAuth `*/authorize` route (Google or Discord) and identity replies `302` with a `Location` to the provider and a `Set-Cookie` for the state cookie
- **THEN** gateway SHALL re-emit `302` with the same `Location` and `Set-Cookie` to the browser; gateway SHALL NOT follow the `Location` itself

#### Scenario: OAuth callback redirect to the frontend is relayed

- **WHEN** a browser requests an OAuth `*/callback` route (Google or Discord) and identity replies `302` with a `Location` to `${FRONTEND_URL}/auth/callback#token=…`
- **THEN** gateway SHALL re-emit the `302` and `Location` verbatim so the browser navigates to the frontend with the fragment intact

### Requirement: rbrain-gateway gates protected routes behind a Bearer JWT

`rbrain-gateway` SHALL expose `POST /chat`, `GET /cards/{scryfall_id}`, `GET /cards`, `GET /rules/{number}`, `POST /decks`, `GET /decks`, `GET /decks/{id}`, `PUT /decks/{id}`, and `DELETE /decks/{id}` as **JWT-protected** reverse proxies — to cortex, lexicon, oracle, and forge respectively. Every protected request SHALL carry a valid `Authorization: Bearer <jwt>` header.

Missing Authorization header, malformed Bearer scheme, signature mismatch, expired token, or HS256-incompatible algorithm SHALL all produce `401 Unauthorized` with body `{"error": "invalid token"}`. The wire response SHALL NOT distinguish among these failure modes — identical body on every 401 path.

JWT verification SHALL use HS256 with the shared `JWT_SECRET` env var (same secret identity uses for signing). On success the gateway SHALL inject `X-User-Id: <sub>` into the forwarded request (and strip any client-supplied `X-User-Id`), as for the other protected routes.

#### Scenario: Valid Bearer JWT proxies the chat to cortex

- **WHEN** a client posts `POST /chat` with `Authorization: Bearer <valid-jwt>` and a body cortex accepts
- **THEN** gateway SHALL verify the JWT, extract the `sub` claim, forward the request to `${CORTEX_URL}/chat` with `X-User-Id: <sub>` injected, and re-emit cortex's response

#### Scenario: Deck save is proxied to forge with the user id

- **WHEN** a client posts `POST /decks` with a valid Bearer JWT
- **THEN** gateway SHALL forward to `${FORGE_URL}/decks` with `X-User-Id: <sub>` injected (and any inbound `X-User-Id` stripped), and re-emit forge's response

#### Scenario: Deck edit and delete are proxied to forge with the user id

- **WHEN** a client sends `PUT /decks/{id}` or `DELETE /decks/{id}` with a valid Bearer JWT
- **THEN** gateway SHALL forward to `${FORGE_URL}/decks/{id}` with `X-User-Id: <sub>` injected and re-emit forge's response

#### Scenario: Missing Authorization header returns 401

- **WHEN** a client posts `POST /chat` without an Authorization header
- **THEN** gateway SHALL return `401 Unauthorized` with `{"error": "invalid token"}`; gateway SHALL NOT forward the request to cortex

#### Scenario: Expired JWT returns 401

- **WHEN** a client posts `GET /cards/<id>` with a JWT whose `exp` is in the past
- **THEN** gateway SHALL return `401 Unauthorized` with `{"error": "invalid token"}`

### Requirement: X-User-Id header forwarding

When forwarding a protected request to a downstream service, `rbrain-gateway` SHALL inject the header `X-User-Id: <sub>` where `<sub>` is the verified JWT `sub` claim (UUID4 string per `identity-api`). Any `X-User-Id` header on the inbound request SHALL be stripped before forwarding to prevent client-side spoofing.

Downstream services MAY consume the header but SHALL NOT trust it without independent verification at v1 — they sit on a private network behind the gateway boundary.

#### Scenario: X-User-Id is injected on protected proxy

- **WHEN** gateway forwards a verified protected request
- **THEN** the outbound request SHALL carry `X-User-Id: <sub>`; the value SHALL match the JWT's `sub` claim

#### Scenario: Inbound X-User-Id is stripped

- **WHEN** a client sends a request with both a valid Bearer JWT and a client-supplied `X-User-Id: someone-else` header
- **THEN** gateway SHALL replace the inbound value with the JWT's `sub`; downstream SHALL NEVER see the client's `X-User-Id`

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

