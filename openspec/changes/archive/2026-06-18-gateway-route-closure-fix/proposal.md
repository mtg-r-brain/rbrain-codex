## Why

`gateway-api`'s "No other public HTTP routes at v1" requirement is the platform's anti-phantom-route guardrail: every public route must be enumerated there, and adding one requires a MODIFIED delta on that requirement. Two prior changes — `forge-deck-persistence` and `deck-edit-delete` — added five `/decks/*` routes to the "gates protected routes" requirement but never updated the closure. As a result the canonical spec asserts "exactly **eleven** public HTTP routes" while actually exposing **sixteen**, and the deck routes are absent from both the closure enumeration and the CORS preflight list. The guardrail is self-inconsistent: the invariant it protects was violated by the very changes that extended the surface it governs.

This is contract-debt cleanup only — no new behavior. It realigns the closure (and CORS) with the routes already shipped, so any later change (e.g. `chronicle-api`) amends a truthful baseline.

## What Changes

- MODIFY `gateway-api` "No other public HTTP routes at v1": count **eleven → sixteen**; add the five already-shipped `/decks/*` routes (`POST /decks`, `GET /decks`, `GET /decks/{id}`, `PUT /decks/{id}`, `DELETE /decks/{id}`) to the enumerated public surface.
- MODIFY `gateway-api` "CORS preflight discipline": add the five `/decks/*` routes to the browser-preflight set (the deck builder issues `POST`/`PUT`/`DELETE` with a JSON body, all of which trigger a CORS preflight).

## Capabilities

### Modified Capabilities

- `gateway-api`: route-closure count and enumeration corrected to include the deck routes; CORS preflight extended to match.

## Impact

- **Contract only**, and **no new route** — this documents routes that already exist in the canonical "protected routes" requirement and in `rbrain-gateway`.
- **No sibling implementation change** required: `rbrain-gateway` already serves these routes. If its CORS layer does not yet preflight `/decks/*`, that is a gateway-side bug this contract now makes explicit.
- **No new sync edge, no schema, no NATS.**
- **Specs touched**: codex `gateway-api`.
