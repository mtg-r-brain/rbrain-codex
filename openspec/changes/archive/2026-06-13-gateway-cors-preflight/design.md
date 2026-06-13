## Context

`gateway-api` is the external contract for `rbrain-gateway`. It enumerates the seven public HTTP routes and the auth discipline around each. Browser-driven access via `rbrain-app` is a first-class deployment topology (Next.js on a separate origin), so CORS preflight is a real contract surface — silently dropping `OPTIONS` requests turns the platform into a non-functional product for browser clients.

This codex change records the **observable** contract; the **implementation** lives in `rbrain-gateway/openspec/changes/gateway-cors-policy` (sibling slice).

## Goals / Non-Goals

**Goals:**

- Spec CORS preflight as a protocol-level concern, distinct from the route-content concern that the existing four requirements cover.
- Make the allowlist a deployment-time concern, not a build-time constant — the same gateway binary must serve dev (`localhost:3000`) and prod (`app.rbrain.example`) without rebuild.
- Document the "no allowlist = no CORS headers" fallback so an out-of-the-box deployment is browser-incompatible by design until explicitly opted in.

**Non-Goals:**

- OAuth2 origin negotiation. Future slice.
- Per-route preflight policies. The same allowlist covers all seven routes.
- Wildcard / regex origin matching. Exact-match list only.

## Decisions

### Decision 1: Allowlist is a deployment env var, not part of the contract

**Choice:** The codex contract says "deployment-configured allowlist" without naming the env var. The gateway repo's slice (`gateway-cors-policy`) names it `CORS_ALLOWED_ORIGINS`.

**Rationale:**

- Env-var names are repo-level discipline, not platform contract.
- Future deployments (k8s ConfigMap, secrets file) may surface the allowlist differently.

### Decision 2: Empty allowlist = no CORS headers, not wildcard

**Choice:** A deployment that does not set the allowlist SHALL emit no `Access-Control-Allow-*` headers. The gateway is browser-incompatible by default; opt-in is explicit.

**Rationale:**

- Wildcard (`Access-Control-Allow-Origin: *`) combined with `Authorization: Bearer` is a documented security footgun (browsers refuse the combination for credentialed requests; allowing it would only encourage misconfiguration).
- A default-off posture means a forgotten `CORS_ALLOWED_ORIGINS` env var produces a loud, debuggable failure (the very symptom that surfaced this change) rather than an opaque XSS attack surface.

### Decision 3: Same allowlist for every public route

**Choice:** Preflight discipline is uniform across `/auth/*`, `/chat`, `/cards`, `/cards/*`, `/rules/*`. Different allowlists per route would multiply config surface without clinical benefit.

**Rationale:**

- All seven public routes share the same `rbrain-app` consumer.
- A future need to expose `/health` to a third-party monitor would be addressed by a separate CORS exemption, not by per-route allowlists.

### Decision 4: Preflight does NOT execute the Bearer-JWT middleware

**Choice:** The CORS layer wraps the entire router (including the protected group). Preflight `OPTIONS` requests SHALL receive a 200 (or 204) response without invoking the Bearer-JWT middleware. The next request from the same browser session — the actual `POST /chat` etc. — still goes through `jwt_middleware`.

**Rationale:**

- This is RFC-compliant CORS behavior: preflight is metadata negotiation, not a real auth event.
- `tower-http`'s `CorsLayer` short-circuits `OPTIONS` before downstream middleware runs, which is the intended behavior.

## Risks / Trade-offs

- **Misconfigured allowlist locks browser clients out silently.** Mitigated by the fact that the failure is loud at the browser console (`No 'Access-Control-Allow-Origin' header is present`) — operators see it immediately.
- **Browser-extension or proxy-rewritten Origin headers could bypass the allowlist** in theory. The gateway trusts the browser to send the real Origin; we accept this in the threat model (the JWT remains the security boundary, CORS is a same-origin policy assist, not an auth mechanism).

## Migration Plan

None. Pre-change deployments that don't ship the gateway-cors-policy slice continue to behave as before (no CORS headers, no browser access). Once the sibling slice is deployed, operators add `CORS_ALLOWED_ORIGINS` to enable browser clients.
