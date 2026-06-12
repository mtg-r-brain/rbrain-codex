## Why

Cortex's chat interface is mostly card-centric today (lookup_card + search_cards via lexicon). The platform's mission is broader: "AI-powered MTG reasoning" includes rules Q&R with citations. The `oracle` bounded context exists in `bounded-contexts/catalog.yaml`, has its scaffolded baseline, and is listed in `service-topology/sync-graph.yaml` as `cortex → oracle` — but nothing on the wire connects them yet. Same situation as cortex had before `cortex-api` was archived.

This change opens the `oracle-api` capability codex-side: the external HTTP contract `rbrain-oracle` must honor. The companion `oracle-rules-storage-mvp` change in `rbrain-oracle` ships the implementation behind it.

Scope is deliberately small at slice 1: exact lookup by rule number only (`GET /rules/{number}`), backed by a `oracle.rules` table holding the Comprehensive Rules as plain text. Semantic search via pgvector, sync from WotC's published rules document, ruling annotations, and the `lookup_rule` cortex tool are all separate follow-up changes. Tracer-bullet first; widen later.

## What Changes

- ADD a new `oracle-api` capability in `rbrain-codex/openspec/specs/oracle-api/spec.md` with four requirements:
  1. `rbrain-oracle` exposes `GET /rules/{number}` (route + caller via the `cortex → oracle` edge)
  2. `200` response carries the `Rule` payload (3 string fields: `number`, `text`, `source`)
  3. `404` response carries a structured error payload
  4. No other public HTTP routes at v1 (closure clause, with `/health` carved out per `repository-conventions`)

No updates to existing codex capabilities:
- `bounded-contexts/catalog.yaml` already lists oracle
- `service-topology/sync-graph.yaml` already carries `cortex → oracle`
- `data-stores` already mandates the `oracle` schema (per the 6-BC list updated in `cortex-persistence`)
- `repository-conventions` already mandates `GET /health` and the closure-clause convention (per `health-and-api-closure-conventions`)

## Capabilities

### New Capabilities

- `oracle-api`: the external HTTP contract `rbrain-oracle` exposes. Owns `GET /rules/{number}` shape and the closure clause on the public route set.

### Modified Capabilities

(none)

## Impact

- **Code**: none in codex. Implementation lives in `rbrain-oracle` under its own `oracle-rules-storage-mvp` change.
- **APIs**: no wire change on any other context. Cortex's `lookup_rule` tool will land in a separate follow-up; until then, `oracle-api` is purely a server-side contract waiting for a client.
- **Dependencies**: none.
- **Specs touched**: codex only. `rbrain-oracle/openspec/specs/oracle-rules-storage-mvp/spec.md` is the implementation companion archived in the oracle repo.
- **Validators**: `validate-api-closure.sh` will pick up the new capability automatically and assert it has a closure clause; the requirement below satisfies that check.
- **Migration**: none.
