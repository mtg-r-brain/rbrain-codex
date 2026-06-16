## Context

The Google delta already established the rule that the gateway relays (not follows) identity's OAuth `3xx` + `Set-Cookie`, and that OAuth routes are unauthenticated identity proxies under `StripAuthOnly`. Discord adds two more routes of the same shape; only the contract's route enumeration needs updating.

## Goals / Non-Goals

**Goals:** authorize the two Discord OAuth routes as public identity proxies; bump the public-route count.

**Non-Goals:** any new behavior (the redirect/cookie relay is unchanged); further providers.

## Decisions

### Decision 1: Reuse the established OAuth route rules

Discord routes are GET, unauthenticated, `StripAuthOnly`, and rely on the same relay-not-follow proxy behavior. No new contract concept — only the route list grows (9 → 11).

## Migration

None — contract text only.
