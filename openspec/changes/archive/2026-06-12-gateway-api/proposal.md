## Why

`rbrain-identity` ships register+login behind the codex identity-api contract; cortex / lexicon / oracle ship their public surfaces. Each is `service-topology`-declared as internal-only — they live behind the gateway invariant ("gateway → cortex", "gateway → identity", etc.). What's missing is the gateway itself.

`rbrain-gateway` is the public ingress: it's the single externally-reachable surface the `rbrain-app` Next.js frontend talks to, and it's where JWT validation happens before requests reach cortex / lexicon / oracle. Slice 1 covers the reverse-proxy + auth middleware needed for an end-to-end demo (UI → gateway → cortex → tools).

OAuth2, refresh tokens, rate limiting, observability, CORS policies — all separate follow-ups.

## What Changes

- ADD a new `gateway-api` capability in `rbrain-codex/openspec/specs/gateway-api/spec.md` with these requirements:
  1. `rbrain-gateway` exposes `POST /auth/register` and `POST /auth/login` as **unauthenticated** proxies to `rbrain-identity`. Request and response bodies pass through unchanged.
  2. `rbrain-gateway` exposes `POST /chat`, `GET /cards/{scryfall_id}`, `GET /cards`, `GET /rules/{number}` as **JWT-protected** proxies to cortex / lexicon / oracle. Missing or invalid Authorization header returns `401`.
  3. Bearer token verification: HS256 with the shared `JWT_SECRET`. Expired tokens return `401`. Tokens issued by identity decode to claims matching the codex `identity-api` contract.
  4. The verified `sub` claim is forwarded to downstream services as `X-User-Id` header. cortex et al. read it for future per-user features (audit, multi-tenant); ignoring it stays safe at v1.
  5. No other public HTTP routes at v1 (closure clause, `/health` carved out per repository-conventions; no `/admin/*` at slice 1).

No updates to existing codex capabilities:
- `service-topology/sync-graph.yaml` already declares `app → gateway`, `gateway → identity`, `gateway → cortex`, `gateway → chronicle`
- `repository-conventions` already mandates `/health` + closure clause + PORT env var
- `language-runtimes` already allocates rust to gateway with a 25 MB budget

## Capabilities

### New Capabilities

- `gateway-api`: the external HTTP contract `rbrain-gateway` exposes. Owns the route surface, the auth discipline, the X-User-Id forwarding contract, and the closure clause.

### Modified Capabilities

(none)

## Impact

- **Code**: none in codex. Implementation lives in `rbrain-gateway` under its own `gateway-bootstrap-mvp` change archived in parallel.
- **APIs**: no wire change on existing siblings. Gateway is a new ingress — downstream services see the same shapes they already serve, optionally augmented with `X-User-Id`.
- **Dependencies**: none.
- **Specs touched**: codex only.
- **Validators**: `validate-api-closure.sh` (existing) picks up the new capability automatically.
- **Auth model**: HS256 JWT shared-secret at v1 — identity signs, gateway verifies with the same `JWT_SECRET`. RS256+JWKs is future v2.
- **Migration**: none.
