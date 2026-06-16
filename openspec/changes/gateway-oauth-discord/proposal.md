## Why

`identity-oauth-discord` added Discord login on identity (`GET /auth/oauth/discord/{authorize,callback}`). The `gateway-api` contract caps the public surface (now nine routes) and names "further OAuth provider routes (e.g. Discord)" as requiring a MODIFIED delta before they ship. This is that delta.

## What Changes

- MODIFY `gateway-api` "rbrain-gateway proxies the identity auth routes unauthenticated": add the two Discord routes to the unauthenticated identity-proxy set (same redirect/`Set-Cookie` relay rule already established for Google).
- MODIFY `gateway-api` "No other public HTTP routes at v1": nine → **eleven** public routes.

## Capabilities

### Modified Capabilities

- `gateway-api`: two MODIFIED requirements (auth-route set + public-route count 9 → 11).

## Impact

- **Contract only** here. Implementation is the sibling `rbrain-gateway` change `gateway-oauth-discord` (two public GET routes; the redirect-relay proxy behavior already shipped with Google).
- **No new sync edge** (proxies to `rbrain-identity`).
- **Specs touched**: codex `gateway-api` only.
