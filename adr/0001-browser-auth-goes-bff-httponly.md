# ADR 0001 — Browser auth moves to a BFF with an httpOnly cookie

- **Status**: Accepted (2026-07-06)
- **Deciders**: Hoani Cross (owner), via strategic-fork review
- **Tracked as**: platform Finding E (carried since 2026-06-13, closed by this decision)

## Context

Since `app-login-and-chat-mvp`, `rbrain-app` stores the identity JWT (7-day TTL) in `localStorage` and attaches it as an `Authorization: Bearer` header from browser-side fetches. Any successful XSS therefore exfiltrates a week-long credential.

Current compensating controls keep the exposure low but not null: no raw-HTML rendering anywhere (react-markdown without `rehype-raw`, spec-enforced in chat and blog), operator-controlled editorial content, localhost-only deployment. The platform, however, aspires beyond a local demo (public deployment is on the horizon via the Helm story), and the deck/chat surfaces will keep growing user-generated content.

## Decision

Adopt the **Backend-for-Frontend pattern** in `rbrain-app`:

1. After login/register/OAuth-callback, the **app server** (Next.js route handlers) holds the JWT and sets it in an **`httpOnly`, `Secure`, `SameSite=Lax` cookie** scoped to the app origin. Browser JavaScript never sees the token.
2. All API traffic from the browser goes **same-origin** to Next route handlers (`/api/*`), which proxy to the gateway **in-network** (`http://gateway:8080`), injecting `Authorization: Bearer <jwt>` read from the cookie.
3. **CSRF**: `SameSite=Lax` plus a custom-header check (`X-Requested-With`) on mutating routes — cross-origin forms cannot set custom headers.
4. The **gateway contract does not change**: it keeps verifying Bearer JWTs and remains the platform's sole API ingress; the app server becomes one of its callers (the existing `app → gateway` topology edge, now exercised server-side). `identity` is untouched.

`localStorage` storage is **deprecated as of this ADR** and is removed when the BFF change ships.

## Consequences

**Positive**: XSS can no longer exfiltrate the token (worst case becomes same-session request forgery, bounded by the cookie's scope and TTL); CORS complexity for the app disappears (same-origin); the browser-facing surface stops depending on `NEXT_PUBLIC_GATEWAY_URL` at build time.

**Negative / cost**: the app server stops being a static shell — route handlers proxy every API call (latency hop, error mapping); a server-side `GATEWAY_URL` env joins the deploy wiring; the OAuth fragment-redirect flow (`#token=`) must be reworked into a server-side callback exchange; app memory budget may need re-measuring under proxy load.

**Work items** (queued as the next app chantier, spec-first):

- `rbrain-app` OpenSpec change `app-bff-auth`: route-handler proxy, cookie lifecycle (set on login/register/callback, clear on logout), CSRF check, removal of `jwt-storage.ts`.
- `rbrain-deploy`: `GATEWAY_URL` (in-network) for the app service; `NEXT_PUBLIC_GATEWAY_URL` build-arg retired.
- codex: `deployment-stack` wiring MODIFY (app env) at ship time; identity OAuth `FRONTEND_URL` redirect flow amended to the server-side callback.

## Alternatives considered

- **Accept localStorage for the demo scope** (with reopen triggers): rejected by the owner — the platform intends to outgrow the demo perimeter, and the migration only gets more expensive as surfaces accumulate.
- **Short TTL + refresh endpoint**: shrinks the exfiltration window but does not eliminate the vector, while adding `identity-api`/gateway churn (`POST /auth/refresh`) that the BFF makes unnecessary. Rejected.
- **In-memory token (no persistence)**: loses the session on every refresh — UX cost without closing the vector (XSS still reads it live). Rejected.
