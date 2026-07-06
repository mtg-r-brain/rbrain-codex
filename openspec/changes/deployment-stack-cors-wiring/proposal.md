## Why

First browser session against the stack (2026-07-06): every page shows "failed to fetch". The gateway's CORS support is env-gated — `CORS_ALLOWED_ORIGINS`, empty list = no `Access-Control-Allow-*` headers at all (`rbrain-gateway/src/lib.rs`) — and the `deployment-stack` "Complete internal environment wiring" requirement enumerates gateway's variables **without it**, so the compose faithfully implemented an unbrowsable stack. June's browser demos worked because the native gateway got the variable from the operator's shell. curl-based smokes never see CORS, which is why the entire item-2 batch stayed green.

## What Changes

- MODIFY `deployment-stack` "Complete internal environment wiring": gateway's variable list gains `CORS_ALLOWED_ORIGINS`, defaulting to the app's browser-facing origin (`http://localhost:3000`), operator-overridable; new scenario asserting the browser origin is CORS-admitted.
- Downstream (sibling commits): `rbrain-deploy` compose + `.env.example`; `rbrain-gateway/.env.example` documents the variable (chore — it was undocumented there too).

## Capabilities

### Modified Capabilities

- `deployment-stack`: gateway wiring made browser-complete.

## Impact

- Config only, no code. Lesson recorded: curl smokes do not exercise CORS — a browser (or Origin-header probe) belongs in the smoke sweep.
