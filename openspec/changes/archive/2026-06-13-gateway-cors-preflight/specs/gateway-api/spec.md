## ADDED Requirements

### Requirement: CORS preflight discipline

`rbrain-gateway` SHALL accept browser CORS preflight `OPTIONS` requests on every public HTTP route declared in this capability (`POST /auth/register`, `POST /auth/login`, `POST /chat`, `GET /cards`, `GET /cards/{scryfall_id}`, `GET /rules/{number}`) and on the platform-wide `GET /health`.

The CORS behavior is gated by a deployment-configured allowlist of permitted browser origins. The codex contract does NOT name the env var or config key; the gateway implementation slice (`gateway-cors-policy` in `rbrain-gateway`) does.

For a preflight `OPTIONS` request whose `Origin` header value is in the deployment-configured allowlist, the gateway SHALL respond with:

- HTTP status `200 OK` (or `204 No Content`).
- `Access-Control-Allow-Origin: <verbatim origin from request>`.
- `Access-Control-Allow-Methods` listing at minimum `GET, POST, OPTIONS`.
- `Access-Control-Allow-Headers` listing at minimum `authorization, content-type`.

For a preflight request whose `Origin` is NOT in the allowlist, the gateway SHALL NOT emit any `Access-Control-Allow-*` header in the response; the browser then enforces the rejection by failing the subsequent fetch.

When the deployment-configured allowlist is empty (the default, no opt-in), the gateway SHALL NOT emit any `Access-Control-Allow-*` header for any origin on any route. The gateway is browser-incompatible by default; deployments enable browser access by setting the allowlist.

The CORS layer SHALL short-circuit `OPTIONS` requests before they reach the Bearer-JWT middleware: preflight is not an auth event. Subsequent non-preflight requests on the protected group continue to go through `jwt_middleware` as specified by the existing Requirement "rbrain-gateway gates protected routes behind a Bearer JWT".

The CORS layer SHALL apply uniformly to all public routes — there is no per-route allowlist; a single deployment-level list covers `/auth/*`, `/health`, `/chat`, `/cards`, `/cards/*`, and `/rules/*`.

#### Scenario: Allowlisted origin preflight on /auth/register

- **WHEN** a browser at origin `http://localhost:3000` (which is in the deployment allowlist) sends `OPTIONS /auth/register` with headers `Origin: http://localhost:3000`, `Access-Control-Request-Method: POST`, `Access-Control-Request-Headers: content-type`
- **THEN** the gateway SHALL respond with `200 OK` (or `204 No Content`); the response headers SHALL include `Access-Control-Allow-Origin: http://localhost:3000`, `Access-Control-Allow-Methods` containing `POST` and `OPTIONS`, and `Access-Control-Allow-Headers` containing `content-type`

#### Scenario: Non-allowlisted origin gets no CORS headers

- **WHEN** a browser at origin `https://evil.example` (NOT in the allowlist) sends a preflight `OPTIONS /chat` request
- **THEN** the response SHALL NOT include any `Access-Control-Allow-Origin` header; the browser SHALL fail the subsequent fetch

#### Scenario: Empty allowlist disables CORS for every origin

- **WHEN** the deployment has no allowlist configured and any browser sends `OPTIONS /chat` with any `Origin`
- **THEN** the response SHALL NOT include any `Access-Control-Allow-*` header on any route

#### Scenario: Preflight does not invoke JWT middleware

- **WHEN** an allowlisted browser sends `OPTIONS /chat` without an `Authorization` header
- **THEN** the gateway SHALL respond `200 OK` (or `204`) with CORS headers; it SHALL NOT respond `401 {"error":"invalid token"}` — preflight is not an auth event
