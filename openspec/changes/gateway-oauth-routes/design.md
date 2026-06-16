## Context

`gateway-api` is the contract; `rbrain-gateway` implements it as a bytes-level reqwest reverse proxy. The seven-route cap and the explicit "OAuth2 callbacks require a MODIFIED delta" clause force this contract change before the OAuth routes can ship.

## Goals / Non-Goals

**Goals:** authorize the two Google OAuth routes as public identity proxies; make redirect + cookie relay a contract guarantee (not an implementation accident).

**Non-Goals:** Discord routes (a later delta adds `/auth/oauth/discord/*` and bumps the count again); changing the protected-route set; any new sync edge.

## Decisions

### Decision 1: Relay redirects, never follow them

The proxy SHALL relay an identity `3xx` (status + `Location` + `Set-Cookie`) to the client unchanged. Following the redirect server-side would (a) on authorize, fetch Google's consent HTML instead of bouncing the browser, and (b) on callback, drop the URL fragment (`#token=`) that the SPA needs. This is the load-bearing behavior the implementation must guarantee (reqwest defaults to following up to 10 redirects, so the impl must disable that on the proxy client).

### Decision 2: OAuth routes are GET, under the existing /auth/* unauthenticated policy

They carry no `Authorization` and need no JWT; they reuse the `StripAuthOnly` policy already governing `/auth/register` and `/auth/login`. The state cookie is the only credential and it round-trips via `Set-Cookie`/`Cookie`, which the proxy already relays.

## Risks / Trade-offs

- **Open redirect surface**: identity (not the gateway) builds the redirect targets — to Google (fixed) and to `FRONTEND_URL` (operator-configured). The gateway relays opaquely. No user-controlled redirect target is introduced at the gateway.

## Migration

None — contract text only.
