## Context

`rbrain-gateway` is the platform's single public ingress per `service-topology`. At slice 1 it does two things: route public requests to internal services, and gate the protected routes behind a JWT check. Future slices add rate limiting, observability (RED metrics), CORS policy, OAuth2 callback handling, error envelope normalisation.

The pattern is well-trodden — Cloudflare/Nginx-as-API-gateway behaviour transposed to a Rust + axum server. Specifically:

- Public routes (`/auth/*`): forwarded without inspection. Identity owns the contract.
- Protected routes (`/chat`, `/cards/*`, `/rules/*`): gateway extracts the Bearer token, verifies HS256 against `JWT_SECRET`, extracts `sub`, forwards downstream with `X-User-Id` header.
- Health: local, no proxy.

Choice space:
- **Per-route handler vs single generic handler.** Per-route lets gateway evolve route-specific behaviour (rate limits, validation). Generic is smaller code. Slice 1 picks generic with route-prefix matching.
- **Bytes-level body forwarding vs typed proxy.** Bytes is generic, supports unknown body shapes. Typed couples gateway to every downstream's request/response model. Slice 1 picks bytes.
- **Streaming vs synchronous.** Cortex's POST /chat is synchronous (no SSE/websockets at v1), so gateway can be synchronous too. Slice 1 picks synchronous.

## Goals / Non-Goals

**Goals:**

- Spec the slice 1 route surface precisely: which routes proxy where, which require JWT.
- Lock the JWT verification discipline: HS256, shared secret, missing/invalid → 401.
- Specify the `X-User-Id` forwarding header so downstream services can rely on it later.
- Stay symmetric in shape with lexicon-api / cortex-api / oracle-api / identity-api.
- Keep the closure clause tight — adding `/auth/refresh`, `/admin/*`, `/me`, etc. requires a MODIFIED.

**Non-Goals:**

- Rate limiting. Future slice.
- Observability / metrics endpoint. Future slice.
- CORS policy. The app is same-origin in dev (via Next.js proxy) and will live behind the gateway in prod. CORS comes when a third-party UI lands.
- OAuth2 callback (`/auth/google/callback`, etc.). Future slice when identity ships OAuth2.
- Per-route rate limits. Future slice.
- Response transformation. Gateway proxies responses verbatim.
- Streaming responses (SSE, WebSocket upgrades). Cortex doesn't stream at v1; gateway doesn't either.
- Caching. Pure pass-through.
- Idempotency keys. Out of scope.

## Decisions

### Decision 1: Bytes-level proxy with reqwest

**Choice:** Gateway reads the full request body into bytes, builds an outbound reqwest call with the same method + path tail + body + filtered headers, and re-emits the response bytes verbatim. No body parsing on the gateway side.

**Rationale:** Three reasons:

1. **Decoupling.** Gateway doesn't need a build dep on every downstream's typed model. When cortex/oracle/lexicon change their payload, gateway keeps working.
2. **Smaller surface.** ~100 lines of proxy code vs ~500 lines of per-route typed handlers.
3. **Future-proof.** When cortex adds a new endpoint (e.g. `POST /chat/streaming`), gateway adds one route line, not a typed proxy implementation.

**Alternatives considered:**

- **Typed proxy with codegen'd clients**: rejected. Premature for a single ingress.
- **NGINX or Envoy sidecar**: rejected. Adds operational complexity for a pure-Rust platform; gateway-as-axum keeps the stack uniform.

### Decision 2: JWT verification via axum middleware on protected routes only

**Choice:** Two route groups in the axum router:

- Public group (`/health`, `/auth/*`): no middleware.
- Protected group (`/chat`, `/cards/*`, `/rules/*`): axum-layered middleware that pulls the Bearer token, runs HS256 verification against `JWT_SECRET`, extracts `sub`, inserts a `UserId(String)` into request extensions. Handlers read the extension and add the `X-User-Id` outbound header.

**Rationale:** Middleware-per-group keeps the JWT logic in one place and avoids a per-handler `if Authorization { ... }` boilerplate. Future slice can swap the middleware (e.g. for RS256 verification or for "any of N keys" rotation) without touching handlers.

### Decision 3: 401 on missing OR invalid token with identical body

**Choice:** Both "Authorization header absent" and "token signature invalid" and "token expired" SHALL produce `401 Unauthorized` with body `{"error": "invalid token"}`. The internal logs distinguish, but the wire response does not.

**Rationale:** Same anti-enumeration discipline as identity's login path. A different message lets attackers probe whether a key is valid without needing a real session.

### Decision 4: `X-User-Id` carries the JWT `sub` claim verbatim

**Choice:** When forwarding a protected request, gateway injects `X-User-Id: <sub>` where `<sub>` is the UUID4 string. Downstream services MAY read it but SHALL NOT trust it without JWT verification (they don't see the JWT itself).

**Rationale:** Single source of truth for the user identifier. cortex et al. can persist `user_id` columns when they're ready. At v1 they ignore the header — the platform stays backward-compatible without coordinated rollout.

### Decision 5: Closure clause forbids any non-listed route

**Choice:** `/health`, `/auth/register`, `/auth/login`, `/chat`, `/cards/{scryfall_id}`, `/cards`, `/rules/{number}` are the only public routes at v1. Adding `/auth/refresh`, `/chat/streaming`, `/me`, `GET /users/{id}`, OAuth2 callback routes — all require a MODIFIED.

**Rationale:** Same brake as the other `<context>-api` capabilities. Caught by `validate-api-closure.sh` automatically.

## Risks / Trade-offs

- **[Risk] Bytes-level proxy can't decorate responses** → Accepted at v1. When error normalisation becomes a real concern, gateway switches to per-route typed handlers for the affected routes. The migration is incremental.

- **[Trade-off] `X-User-Id` is trusted by downstream services without re-verification** → Accepted at v1 because downstream services are network-internal. When cortex needs to enforce per-user policy, it can re-verify the JWT (which gateway would need to forward as `X-Forwarded-Authorization` or similar — a future slice).

- **[Risk] JWT_SECRET out-of-band rotation across identity + gateway** → Accepted at v1. Both services read the same env var. Future rotation strategy adds a `JWT_SECRET_NEXT` for graceful migration.

- **[Trade-off] No streaming means future `POST /chat/streaming` requires gateway changes** → Accepted. The streaming endpoint isn't on any roadmap; cortex's sync POST /chat is the contract.

## Open Questions

None at slice 1.
