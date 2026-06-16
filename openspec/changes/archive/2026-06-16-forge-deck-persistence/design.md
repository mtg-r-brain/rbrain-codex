## Context

forge currently parses (stateless) and is a cortex-only tool per `sync-graph.yaml`. User-scoped deck storage requires (a) a place to store decks keyed by owner, and (b) a browser-reachable path, i.e. a `gateway → forge` edge with the gateway's existing `X-User-Id` injection.

## Goals / Non-Goals

**Goals:** save a deck owned by the authenticated user; read back own decks; the contract changes that authorize the gateway→forge path and the protected routes.

**Non-Goals:** sharing/public decks; deck editing/delete (later); legality/analysis; pagination beyond a simple list.

## Decisions

### Decision 1: `gateway → forge` edge, forge dual-role (see proposal ADR)

Added to `sync-graph.yaml`. The existing "tool service not directly callable from gateway" scenario (lexicon) stays true; forge is explicitly the exception because it owns user data (decks), not just derived tool answers.

### Decision 2: Ownership via trusted `X-User-Id`

forge does not verify JWTs (that is the gateway's job). On the deck routes it trusts the gateway-injected `X-User-Id` header as the owner. A request without `X-User-Id` (i.e. not arriving through the gateway's protected path) SHALL be rejected `401` — forge will not store or return an unattributed deck. `GET /decks/{id}` returns `404` when the deck exists but belongs to another user (no existence leak).

### Decision 3: Routes + shapes

- `POST /decks` — body `{ name?: string, decklist: string }`; forge parses, stores `{id, user_id, name, mainboard/sideboard/commander/maybeboard, total_mainboard, created_at}`, returns `201 { id, name, ...parsed }`.
- `GET /decks` — list the caller's decks as summaries `{ id, name, total_mainboard, created_at }`.
- `GET /decks/{id}` — the caller's full deck, or `404`.

Persisted shape stores the parsed sections as JSONB; parse `errors` are returned by `/decks/parse` but NOT stored (a stored deck is the accepted result).

### Decision 4: forge gets its own Postgres (`forge` schema, `:5437`)

Per `data-stores`, forge owns the `forge` schema; local dev Postgres on `5437` (canonical port map). sqlx migrations at boot, mirroring the other Rust services.

## Risks / Trade-offs

- **forge now holds user data** → it must never serve a deck to a non-owner. Enforced by always filtering queries on `user_id` and returning `404` on owner mismatch.
- **`X-User-Id` trust** is only safe because forge is not publicly reachable (only via the gateway, which strips any client-supplied `X-User-Id` and injects the verified one). The new edge does not expose forge publicly.

## Migration

forge migration `0001_create_decks.sql` (new DB). No data migration (first persistence).
