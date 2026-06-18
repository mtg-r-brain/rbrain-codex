## Context

The `gateway-api` capability carries two requirements that must agree on the public route set: "rbrain-gateway gates protected routes behind a Bearer JWT" (the operative list) and "No other public HTTP routes at v1" (the closure/guardrail). The closure also feeds "CORS preflight discipline", which must preflight every public route. When `forge-deck-persistence` and `deck-edit-delete` extended the protected list with five `/decks/*` routes, only the operative requirement was edited; the closure count, the closure enumeration, and the CORS list were left at their pre-deck values.

## Goals

- Make the closure requirement state the true public surface (sixteen routes) and enumerate the deck routes.
- Extend CORS preflight to the deck routes, which the browser deck builder genuinely needs (`POST`/`PUT`/`DELETE` + JSON body all trigger preflight).
- Change nothing about behavior — every route already exists.

## Decisions

- **Single capability, MODIFY-only.** No `ADDED`/`REMOVED` deltas; this is a faithfulness correction to two existing requirements.
- **Count stated as a word ("sixteen").** Matches the existing spec style ("eleven") so the guardrail keeps reading naturally; the enumeration is the real check, the number is a tripwire.
- **No sibling change spawned.** `rbrain-gateway` already serves the deck routes. The only latent risk is that its CORS layer was never wired for `/decks/*`; this contract now makes that obligation explicit so a gateway-side check can confirm it. Flagged in tasks, not assumed broken.

## Why a standalone change (not folded into chronicle-api)

Mixing a debt correction to already-archived work with a brand-new capability would produce a non-atomic commit and blur the archive history. Fixing the closure first means `chronicle-api` later amends a truthful baseline rather than inheriting and silently perpetuating the drift.

## Risks / Trade-offs

- **Low risk.** Documentation-faithfulness only. The worst case is discovering the gateway implementation does not yet preflight `/decks/*` — which is a real bug this change surfaces rather than introduces.
