## MODIFIED Requirements

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

### Requirement: No other public HTTP routes at v1

`rbrain-gateway` SHALL expose exactly eleven **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `POST /auth/register`, `POST /auth/login`, `GET /auth/oauth/google/authorize`, `GET /auth/oauth/google/callback`, `GET /auth/oauth/discord/authorize`, and `GET /auth/oauth/discord/callback` (the identity auth proxies), `POST /chat`, `GET /cards/{scryfall_id}`, `GET /cards`, and `GET /rules/{number}`. Any additional public route — `POST /auth/refresh`, `POST /chat/streaming`, `GET /me`, further OAuth provider routes, password-reset routes — requires a MODIFIED delta on `gateway-api` before the route ships.

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
