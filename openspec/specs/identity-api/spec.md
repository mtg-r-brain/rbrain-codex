# identity-api Specification

## Purpose
TBD - created by archiving change identity-api. Update Purpose after archive.
## Requirements
### Requirement: rbrain-identity exposes POST /auth/register

`rbrain-identity` SHALL expose an HTTP endpoint at the path `POST /auth/register` on its declared service port. The endpoint accepts a JSON request body and returns a JSON response body. Streaming responses are NOT supported at v1.

Callers reachable by this endpoint follow the synchronous call graph in `service-topology/sync-graph.yaml`. At v1, the only declared in-cluster caller is `rbrain-gateway` via the `gateway → identity` edge.

#### Scenario: gateway calls POST /auth/register

- **WHEN** `rbrain-gateway` issues `POST /auth/register` against `rbrain-identity` with a valid request body
- **THEN** the request SHALL reach the identity handler and produce either the 201 response defined below or a 4xx validation response

### Requirement: POST /auth/register request and response shapes

The `POST /auth/register` request body SHALL be a JSON object with exactly the two fields below:

| Field      | Type   | Required | Description                                                   |
|------------|--------|----------|---------------------------------------------------------------|
| `email`    | string | yes      | The user's email address. Must parse as a syntactically valid email. |
| `password` | string | yes      | The user's password. Minimum length 8 characters, maximum 256. |

No other fields SHALL appear in the request body. The handler SHALL reject any extra field with `422 Unprocessable Entity`.

On success, the response SHALL be:

- Status: `201 Created`
- `Content-Type: application/json`
- Body: a JSON object with exactly the three fields below:

| Field         | Type    | Description                                                              |
|---------------|---------|--------------------------------------------------------------------------|
| `token`       | string  | The freshly-issued JWT (HS256-signed) for the newly created user.        |
| `token_type`  | string  | Constant value `"Bearer"` (matches OAuth2 RFC 6749).                     |
| `expires_in`  | integer | Token TTL in seconds. At v1 this SHALL be `604800` (7 days).             |

On a duplicate email, the response SHALL be `409 Conflict` with `{"error": "email already registered"}`. On a malformed email or short password, the response SHALL be `422 Unprocessable Entity` with `{"error": "<message>"}`.

#### Scenario: Successful register issues a JWT

- **WHEN** a client posts `{"email":"alice@example.com","password":"hunter2!secure"}` and the email is not yet registered
- **THEN** the response SHALL be `201 Created` with `{"token":"<jwt>","token_type":"Bearer","expires_in":604800}`; the JWT SHALL decode to claims containing the user's UUID4 and the supplied email

#### Scenario: Duplicate email returns 409

- **WHEN** a client posts a registration with an email that already exists
- **THEN** the response SHALL be `409 Conflict` with `{"error":"email already registered"}`; no new user row SHALL be created

#### Scenario: Malformed email is rejected

- **WHEN** a client posts `{"email":"not-an-email","password":"validpassword"}`
- **THEN** the response SHALL be `422 Unprocessable Entity`; no user row SHALL be created

#### Scenario: Short password is rejected

- **WHEN** a client posts `{"email":"alice@example.com","password":"short"}`
- **THEN** the response SHALL be `422 Unprocessable Entity`; no user row SHALL be created

### Requirement: rbrain-identity exposes POST /auth/login

`rbrain-identity` SHALL expose an HTTP endpoint at the path `POST /auth/login`. The endpoint accepts the same JSON request body shape as `POST /auth/register` (`{email, password}`) and returns the same JWT envelope on success.

#### Scenario: Successful login issues a fresh JWT

- **WHEN** a client posts `{"email":"alice@example.com","password":"hunter2!secure"}` matching an existing user
- **THEN** the response SHALL be `200 OK` with `{"token":"<jwt>","token_type":"Bearer","expires_in":604800}`; the JWT SHALL decode to the same user's UUID and email

#### Scenario: Unknown email returns 401

- **WHEN** a client posts an email that does not correspond to any user
- **THEN** the response SHALL be `401 Unauthorized` with `{"error":"invalid credentials"}`; the response SHALL NOT distinguish between "unknown email" and "wrong password" to avoid leaking user enumeration

#### Scenario: Wrong password returns 401

- **WHEN** a client posts a known email with a wrong password
- **THEN** the response SHALL be `401 Unauthorized` with `{"error":"invalid credentials"}`; same body as the unknown-email case

### Requirement: JWT claims contract

Every JWT issued by `POST /auth/register` and `POST /auth/login` SHALL be signed with `HS256` and SHALL carry exactly the four claims below:

| Claim   | Type    | Description                                                       |
|---------|---------|-------------------------------------------------------------------|
| `sub`   | string  | The user's UUID4 (same value as `users.id` in the identity DB).   |
| `email` | string  | The user's email (same value as `users.email`).                   |
| `iat`   | integer | UNIX timestamp when the token was issued.                         |
| `exp`   | integer | UNIX timestamp when the token expires. At v1 SHALL equal `iat + 604800` (7 days). |

Extra claims (`aud`, `iss`, `jti`, `nbf`, custom fields) are forbidden at v1. Adding a claim requires a MODIFIED delta on this requirement.

#### Scenario: Decoded JWT carries the four claims

- **WHEN** an issued JWT is decoded with the shared `JWT_SECRET`
- **THEN** the claims SHALL be exactly `{sub: "<uuid4>", email: "<email>", iat: <unix>, exp: <iat+604800>}`; no other claims SHALL appear

#### Scenario: HS256 is the signing algorithm

- **WHEN** an issued JWT's header is decoded
- **THEN** `alg` SHALL be `"HS256"` and `typ` SHALL be `"JWT"`; no other algorithm SHALL be accepted by gateway-side verification

### Requirement: No other public HTTP routes at v1

`rbrain-identity` SHALL expose exactly three **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `POST /auth/register` (defined here), and `POST /auth/login` (defined here). Any additional public route — `POST /auth/refresh`, `GET /me`, `PATCH /me`, `DELETE /me`, `GET /users/{id}`, OAuth2 routes, password-reset routes — requires a MODIFIED delta on `identity-api` before the route ships.

At v1, `rbrain-identity` SHALL NOT expose any `/admin/*` route. Should an operator-only endpoint surface later (force-logout, key rotation), an `/admin/*` carve-out comparable to `lexicon-api-admin-carveout` SHALL be introduced via its own OpenSpec change.

#### Scenario: New public endpoint goes through OpenSpec

- **WHEN** a contributor adds `POST /auth/refresh` or `GET /me` to identity
- **THEN** the change SHALL include a MODIFIED requirement on this spec; CI on identity ALONE is not enough to make the new endpoint part of the public surface

#### Scenario: /health does not need an identity-api requirement

- **WHEN** a contributor reads identity-api/spec.md looking for `/health`
- **THEN** they SHALL find it referenced here as out-of-scope-for-this-capability and authoritative in `repository-conventions`; this spec SHALL NOT restate the `/health` contract

#### Scenario: Admin route requires a carve-out change first

- **WHEN** a contributor proposes `POST /admin/force-logout` against identity
- **THEN** the change SHALL include both a new `/admin/*` carve-out requirement on `identity-api` (mirroring `lexicon-api-admin-carveout`) AND the per-endpoint spec; merging the endpoint without the carve-out SHALL fail the closure clause

