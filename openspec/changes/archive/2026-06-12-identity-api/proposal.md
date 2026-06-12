## Why

The vision doc (`ideas/01-project-vision.md`) lists "User accounts (free tier; saves decks and chat history)" and "conversational chat with history (requires account)" as core features. Three production-ready BCs ship today (lexicon + cortex + oracle) without any caller authentication — internal-only by network topology per `service-topology`. To unblock a real frontend (`rbrain-app` Next.js) and `rbrain-gateway` (the public ingress), the platform needs an identity service.

This change opens the `identity-api` codex capability — the external HTTP contract `rbrain-identity` exposes. Slice 1 covers the minimum auth surface for the user-account flow: register + login → JWT. OAuth2 (Google, Discord), refresh tokens, password reset, profile editing, and account deletion are all separate follow-ups.

## What Changes

- ADD a new `identity-api` capability in `rbrain-codex/openspec/specs/identity-api/spec.md` with five requirements:
  1. `rbrain-identity` exposes `POST /auth/register` (route + caller invariant via `gateway → identity` edge)
  2. `POST /auth/register` request + response body shapes
  3. `rbrain-identity` exposes `POST /auth/login` (route)
  4. `POST /auth/login` request + response body shapes (same JWT envelope as register)
  5. JWT claims contract: `sub` (user uuid), `email`, `iat`, `exp`. HS256 at v1.
  6. No other public HTTP routes at v1 (closure clause, `/health` carve-out per repository-conventions; no `/admin/*` at slice 1)

No updates to existing codex capabilities:
- `bounded-contexts/catalog.yaml` already lists identity
- `service-topology/sync-graph.yaml` already declares `gateway → identity`
- `data-stores` already lists identity as one of the 6 persistent BCs (oracle was added via cortex-persistence; identity was in the original 5)
- `repository-conventions` already mandates `GET /health` + closure clause
- `language-runtimes` already allocates rust to identity with a 30 MB budget

## Capabilities

### New Capabilities

- `identity-api`: the external HTTP contract `rbrain-identity` exposes. Owns the two auth endpoints, the JWT envelope shape, the JWT claims contract, and the closure clause.

### Modified Capabilities

(none)

## Impact

- **Code**: none in codex. Implementation lives in `rbrain-identity` under its own `identity-bootstrap-mvp` change archived in parallel.
- **APIs**: no wire change on any other context. Gateway's eventual JWT-validation middleware consumes this contract; cortex's existing endpoints are unaffected at v1 (they trust the gateway).
- **Dependencies**: none.
- **Specs touched**: codex only.
- **Validators**: `validate-api-closure.sh` (existing) picks up the new capability automatically and requires the canonical closure clause phrasing.
- **Migration**: none.
- **Auth model**: shared-secret JWT (HS256) at v1 — identity signs, gateway verifies with the same `JWT_SECRET`. RS256 with JWKs is a future v2 concern.
