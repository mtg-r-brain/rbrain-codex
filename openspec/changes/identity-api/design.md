## Context

`rbrain-identity` is one of two HTTP-serving siblings still empty (the other is gateway). The vision puts it on the critical path for the end-to-end demo: every Q&A turn from a logged-in user goes `app → gateway → cortex → tools`, and gateway needs a way to verify the caller. JWT is the well-trodden answer.

`rbrain-app`'s flow will be: register or login → store JWT in localStorage → send `Authorization: Bearer <jwt>` on every gateway request → gateway validates → forwards to cortex with `X-User-Id: <uuid>` header. Slice 1 covers the identity side of this loop. Gateway's slice 1 (next change) consumes it.

Choice space at this slice:
- Argon2id vs bcrypt vs scrypt for password hashing → modern best practice is Argon2id (OWASP cheat sheet, 2025+).
- HS256 vs RS256 → HS256 with a shared secret keeps slice 1 trivially small. JWKs + RS256 is a v2 concern when the platform has multiple verifiers.
- Refresh tokens → not at slice 1. 7-day access token TTL is good enough until the app needs longer sessions or token rotation.
- Email verification → not at slice 1. OAuth2 (Google/Discord) implicitly carries verification; the email/password path at v1 accepts unverified emails.

## Goals / Non-Goals

**Goals:**

- Specify `POST /auth/register` and `POST /auth/login` as the only two public auth endpoints at v1.
- Anchor the JWT envelope (`{token, token_type, expires_in}`) and the JWT claims contract (sub, email, iat, exp).
- Lock the closure clause so a future contributor can't slip in `POST /auth/refresh` or `GET /me` without OpenSpec review.
- Stay symmetric with lexicon-api / cortex-api / oracle-api in shape and tone.

**Non-Goals:**

- OAuth2 (Google, Discord). Future change adds the consent flow + identity-provider mapping; the shape will reuse the same JWT envelope.
- Refresh tokens. The 7-day access token TTL is the v1 session length.
- Password reset flow. Future change adds the email-driven reset.
- Profile editing (name, avatar). Out of scope until needed.
- Account deletion. Out of scope until GDPR concerns become operational.
- Multi-factor auth. Future change.
- Per-endpoint rate limiting. Gateway handles this for the platform.
- `/admin/*` routes. Identity has no operator endpoint at v1; the carve-out lands when one shows up.

## Decisions

### Decision 1: HS256 JWT with a shared `JWT_SECRET` at v1

**Choice:** Identity signs with HS256 using `JWT_SECRET` env var. Gateway verifies with the same secret. RS256 + JWKs is deferred.

**Rationale:** Three reasons:

1. **Smallest viable.** Shared-secret JWT removes a JWKs endpoint, key rotation tooling, and asymmetric crypto setup from slice 1.
2. **Single trust boundary.** Only gateway verifies at v1; cortex/lexicon/oracle don't see JWTs (gateway forwards `X-User-Id`). Shared secret matches that topology.
3. **Migration path is clean.** Moving to RS256/JWKs is purely additive: identity adds a `/jwks.json` endpoint, gateway switches verifier. The wire shape of the token doesn't change.

**Alternatives considered:**

- **RS256 + JWKs from day 1**: rejected. Premature for v1 with one verifier.
- **PASETO**: rejected. Less library support, smaller pool of reviewer familiarity; HS256 JWT is the universal default.

### Decision 2: Argon2id for password hashing

**Choice:** Argon2id with sensible defaults (memory=64 MiB, iterations=3, parallelism=4 — matches OWASP cheat sheet's "Argon2id" row).

**Rationale:** OWASP-recommended modern default. Resistance to both GPU and side-channel attacks. The `argon2` crate is mature.

**Alternatives considered:**

- **bcrypt**: rejected. Still widely used but Argon2id is the modern best practice; choosing bcrypt would be deliberately ageing the implementation.
- **scrypt**: rejected. Less library momentum, less reviewer familiarity than Argon2id.

### Decision 3: Three-field response envelope `{token, token_type, expires_in}`

**Choice:** Both `POST /auth/register` and `POST /auth/login` return:

```json
{
  "token": "<jwt-string>",
  "token_type": "Bearer",
  "expires_in": 604800
}
```

`token_type` is the OAuth2 RFC 6749 standard value. `expires_in` matches the JWT's `exp - iat` in seconds (7 days = 604800).

**Rationale:** OAuth2-shaped envelope makes the response immediately usable by any OAuth2-aware client library. Identity doesn't speak full OAuth2 today, but the response shape doesn't lie about it either.

### Decision 4: JWT claims contract is exactly four fields

**Choice:** `sub` (UUID4 string), `email`, `iat`, `exp`. No `aud`, `iss`, `jti`, `nbf` at v1.

**Rationale:** Smallest set that lets gateway identify the user and verify expiry. `aud`/`iss` matter when multiple verifiers exist (v2). `jti` matters for token revocation (v2). `nbf` matters for time-skewed clusters (v2 ops).

### Decision 5: Closure clause forbids any other public route at v1

**Choice:** `POST /auth/register` + `POST /auth/login` + `GET /health` are the only public routes. Adding `POST /auth/refresh`, `GET /me`, `PATCH /me`, `DELETE /me`, `GET /users/{id}` requires a MODIFIED on `identity-api`. No `/admin/*` carve-out at v1 (no operator endpoint exists yet).

**Rationale:** Same brake as lexicon-api/cortex-api/oracle-api. Caught by `validate-api-closure.sh` automatically.

## Risks / Trade-offs

- **[Risk] Shared `JWT_SECRET` leaks → every issued token is forgeable** → Mitigation: secret lives in env var injected by deployment, never in code. Future RS256 migration removes the single-point-of-trust property entirely.

- **[Trade-off] No refresh token means sessions expire hard at 7 days** → Accepted at v1. Users re-login. When session length becomes a real complaint, add a refresh endpoint.

- **[Risk] Email collisions on register (race: two simultaneous registers with the same email)** → Mitigation: Postgres unique constraint on `email`. Second register surfaces as `409 Conflict`.

- **[Trade-off] No email verification means anyone can register any email** → Accepted at v1. The mitigation is operational (rate limiting at gateway) plus the OAuth2 paths landing in slice 2.

- **[Risk] Argon2 memory cost (64 MiB per hash) under sudden load** → Mitigation: identity's 30 MB memory budget is per-process baseline; per-request Argon2 hash bumps RSS during the hash call but releases after. Concurrent registers cap at the gateway's rate limit.

## Open Questions

None at slice 1.
