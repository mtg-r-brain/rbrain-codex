## Why

`forge-deck-parsing` shipped stateless deck parsing. The next slice lets a user **save** a parsed deck and read it back — user-scoped persistence (chosen account model: decks belong to the authenticated user). This makes forge a real CRUD backend for decks, not only a cortex tool.

## Decision (ADR): a new `gateway → forge` synchronous edge

User-scoped deck CRUD is reached by the browser through the gateway, so it needs a direct `gateway → forge` edge. Today `sync-graph.yaml` makes forge reachable **only** from cortex (as an agent tool). This change adds `gateway → forge` to the graph.

- It keeps the graph a DAG (forge calls nothing downstream).
- forge becomes **dual-role**: a cortex agent-tool backend (parse/analyze) AND a direct gateway-fronted CRUD backend (deck storage). The alternative — routing CRUD through cortex (app→gateway→cortex→forge) — was rejected: cortex is the LLM orchestrator, not a CRUD proxy, and that would entangle deck storage with the agent loop.

If this architectural direction is unwanted, this is the change to revert.

## What Changes (contract)

- MODIFY `service-topology` "Authoritative synchronous call graph": add the `gateway → forge` edge (deck CRUD); update `sync-graph.yaml`.
- MODIFY `gateway-api` "gates protected routes behind a Bearer JWT": add `POST /decks`, `GET /decks`, `GET /decks/{id}` as JWT-protected proxies to forge (gateway injects `X-User-Id` from the JWT `sub`, as it already does for cortex/lexicon/oracle).
- MODIFY `forge-api`: ADD the three deck-persistence routes and the rule that forge scopes decks by the inbound `X-User-Id` (trusted, gateway-injected); bump the route enumeration from 2 to 5.

## Capabilities

### Modified Capabilities

- `service-topology`: new `gateway → forge` edge.
- `gateway-api`: deck CRUD added to the protected route set.
- `forge-api`: deck-persistence routes + `X-User-Id` ownership contract.

## Impact

- **Contract only** here. Implementations: `rbrain-forge` change `forge-deck-persistence` (Postgres on `:5437`, `forge` schema, `decks` table, sqlx, store, handlers reading `X-User-Id`) and `rbrain-gateway` change `gateway-deck-routes` (three protected routes).
- **DAG**: remains acyclic.
- **Specs touched**: codex `service-topology`, `gateway-api`, `forge-api`.
