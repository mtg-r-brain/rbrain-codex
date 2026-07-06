## Why

ADR 0001's BFF shipped in rbrain-app: the browser no longer talks to the gateway directly — the app server proxies `/api/*` in-network and the JWT lives in an httpOnly cookie. The `deployment-stack` wiring requirement still describes the old build-time browser-facing URL.

## What Changes

- MODIFY `deployment-stack` "Complete internal environment wiring": app receives `GATEWAY_URL` (in-network, BFF proxy) and `PUBLIC_GATEWAY_URL` (browser-facing, OAuth navigation only); new scenario asserting no gateway URL is baked into the client bundle.

## Capabilities

### Modified Capabilities

- `deployment-stack`: app wiring aligned with ADR 0001.

## Impact

- Contract text; the compose change ships alongside in rbrain-deploy.
