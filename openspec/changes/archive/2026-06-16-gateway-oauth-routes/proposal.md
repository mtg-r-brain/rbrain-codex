## Why

`identity-oauth-google` shipped the Google OAuth flow on `rbrain-identity` (`GET /auth/oauth/google/authorize` and `/auth/oauth/google/callback`). For a browser to reach them, the gateway must expose them publicly. The `gateway-api` contract caps the public surface at seven routes and explicitly names "OAuth2 callbacks" as requiring a MODIFIED delta here before they ship. This change is that delta.

OAuth introduces a behavior the existing proxied routes never exercised: identity replies with `3xx` redirects (authorize → provider; callback → frontend) and `Set-Cookie` (the signed state cookie). The gateway must **relay** these to the browser, not follow them — so the contract is tightened to say so.

## What Changes

- MODIFY `gateway-api` "rbrain-gateway proxies the identity auth routes unauthenticated": add `GET /auth/oauth/google/authorize` and `GET /auth/oauth/google/callback` to the unauthenticated identity-proxy set, and require the proxy to relay `3xx` responses (`Location`) and `Set-Cookie` verbatim without following the redirect.
- MODIFY `gateway-api` "No other public HTTP routes at v1": seven → **nine** public routes (the two OAuth routes added).

## Capabilities

### Modified Capabilities

- `gateway-api`: two MODIFIED requirements (auth-route proxying incl. redirect/cookie relay; public-route count 7 → 9).

## Impact

- **Contract only** in this repo. Implementation lands in the sibling `rbrain-gateway` change `gateway-oauth-routes` (disable reqwest redirect-following on the proxy client; register the two public GET routes; test redirect+cookie passthrough).
- **No new sync edge**: the routes proxy to `rbrain-identity`, an edge already in `service-topology`'s `sync-graph.yaml` (`gateway → identity`).
- **Specs touched**: codex `gateway-api` only.
