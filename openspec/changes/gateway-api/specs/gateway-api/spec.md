## ADDED Requirements

### Requirement: rbrain-gateway proxies the identity auth routes unauthenticated

`rbrain-gateway` SHALL expose `POST /auth/register` and `POST /auth/login` as **unauthenticated** reverse proxies to `rbrain-identity`. The request body, request headers (except `Host` and `Authorization`), HTTP method, and response body/status/headers SHALL pass through unchanged.

These two routes SHALL NOT require an Authorization header. Any Authorization header on these routes SHALL be stripped before forwarding.

#### Scenario: register flows through gateway to identity

- **WHEN** a client posts `POST /auth/register` against gateway with a valid identity-api request body
- **THEN** gateway SHALL forward the request to `${IDENTITY_URL}/auth/register`; the response status, body, and content-type SHALL be re-emitted verbatim from identity

#### Scenario: login flows through gateway to identity

- **WHEN** a client posts `POST /auth/login`
- **THEN** gateway SHALL forward to `${IDENTITY_URL}/auth/login`; identity's `200 + JWT envelope` or `401 + invalid-credentials` response SHALL flow back verbatim

#### Scenario: Authorization on /auth/* is stripped

- **WHEN** a client posts `POST /auth/login` with `Authorization: Bearer <something>`
- **THEN** gateway SHALL strip the Authorization header before forwarding; identity SHALL NOT see it

### Requirement: rbrain-gateway gates protected routes behind a Bearer JWT

`rbrain-gateway` SHALL expose `POST /chat`, `GET /cards/{scryfall_id}`, `GET /cards`, `GET /rules/{number}` as **JWT-protected** reverse proxies to cortex, lexicon, and oracle respectively. Every protected request SHALL carry a valid `Authorization: Bearer <jwt>` header.

Missing Authorization header, malformed Bearer scheme, signature mismatch, expired token, or HS256-incompatible algorithm SHALL all produce `401 Unauthorized` with body `{"error": "invalid token"}`. The wire response SHALL NOT distinguish among these failure modes — identical body on every 401 path.

JWT verification SHALL use HS256 with the shared `JWT_SECRET` env var (same secret identity uses for signing).

#### Scenario: Valid Bearer JWT proxies the chat to cortex

- **WHEN** a client posts `POST /chat` with `Authorization: Bearer <valid-jwt>` and a body cortex accepts
- **THEN** gateway SHALL verify the JWT, extract the `sub` claim, forward the request to `${CORTEX_URL}/chat` with `X-User-Id: <sub>` injected, and re-emit cortex's response

#### Scenario: Missing Authorization header returns 401

- **WHEN** a client posts `POST /chat` without an Authorization header
- **THEN** gateway SHALL return `401 Unauthorized` with `{"error": "invalid token"}`; gateway SHALL NOT forward the request to cortex

#### Scenario: Expired JWT returns 401

- **WHEN** a client posts `GET /cards/<id>` with a JWT whose `exp` is in the past
- **THEN** gateway SHALL return `401 Unauthorized` with `{"error": "invalid token"}`; lexicon SHALL NOT receive the request

#### Scenario: Malformed JWT returns 401

- **WHEN** a client posts `GET /rules/100.1` with `Authorization: Bearer not-a-jwt`
- **THEN** gateway SHALL return `401 Unauthorized` with the same body; oracle SHALL NOT receive the request

#### Scenario: 401 bodies are identical across failure modes

- **WHEN** a client posts the same request with (a) no Authorization header, (b) an expired JWT, (c) a signature-mismatched JWT
- **THEN** all three responses SHALL be `401 Unauthorized` with body byte-equal to `{"error":"invalid token"}`; no header SHALL distinguish them

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

`rbrain-gateway` SHALL expose exactly these **public** HTTP routes at v1:

- `GET /health` (defined by `repository-conventions`)
- `POST /auth/register` and `POST /auth/login` (defined here)
- `POST /chat`, `GET /cards/{scryfall_id}`, `GET /cards`, `GET /rules/{number}` (defined here)

Any additional public route — `POST /auth/refresh`, `POST /chat/streaming`, `GET /me`, OAuth2 callbacks, password-reset routes — requires a MODIFIED delta on `gateway-api` before the route ships.

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
