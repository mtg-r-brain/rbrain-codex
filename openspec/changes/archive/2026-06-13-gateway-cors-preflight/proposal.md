## Why

`gateway-api` defines seven public HTTP routes today, but never spelled out the browser-side preflight discipline. When `rbrain-app` (Next.js on `:3000`) first POSTed to `/auth/register` on the gateway (`:8090`) from a browser, the request was blocked by the browser's CORS policy: the gateway returned no `Access-Control-Allow-Origin` header on the `OPTIONS` preflight. The platform's first browser-driven end-to-end demo failed at the very first user action.

This slice adds one ADDED requirement to `gateway-api` that codifies the CORS preflight contract: the gateway SHALL honor browser preflight OPTIONS for the seven public routes when the request's `Origin` is in the deployment's configured allowlist; it SHALL emit no CORS headers (and let the browser reject the request) for any other origin. The allowlist is a deployment-time concern (env var on the gateway) and not part of the codex contract.

OAuth2 origin negotiation, multi-tenant origin discovery, dynamic origin registration — all deferred.

## What Changes

- ADD `Requirement: CORS preflight discipline` to `openspec/specs/gateway-api/spec.md`. Body summary:
  - `rbrain-gateway` SHALL accept browser CORS preflight `OPTIONS` requests on every public route (`/auth/*`, `/chat`, `/cards`, `/cards/*`, `/rules/*`).
  - For requests whose `Origin` header is in the deployment-configured allowlist, the response SHALL include `Access-Control-Allow-Origin: <origin>`, `Access-Control-Allow-Methods` covering `GET, POST, OPTIONS`, and `Access-Control-Allow-Headers` covering at minimum `authorization, content-type`.
  - For requests whose `Origin` is NOT in the allowlist, the gateway SHALL NOT emit any `Access-Control-Allow-*` header; the browser then enforces the rejection.
  - When no allowlist is configured (empty), the gateway SHALL emit no CORS headers for any origin (the browser-driven path is implicitly disabled at the deployment).
  - The CORS layer SHALL NOT mutate or inspect bearer tokens; the existing Bearer-JWT middleware still gates non-preflight access.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `gateway-api`: 1 ADDED Requirement (CORS preflight). The existing four requirements are unchanged.

## Impact

- **Code**: requires a sibling change in `rbrain-gateway` (`gateway-cors-policy`) to implement the contract via a `CORS_ALLOWED_ORIGINS` env var and `tower-http`'s `cors` feature.
- **Migration**: none. Deployments not setting `CORS_ALLOWED_ORIGINS` continue to behave exactly as before (no CORS headers emitted), which is the pre-change behavior.
- **CI**: existing.
- **Demo footnote**: this change formalizes the quick fix that landed during the 2026-06-13 browser smoke; the gateway impl preceded the OpenSpec change by ~30 minutes (acceptable in this case because the smoke discovered the lacuna and the impl was minimal — both are now consolidated under the same date).
