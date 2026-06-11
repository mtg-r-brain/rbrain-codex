## Why

`rbrain-lexicon` shipped its first vertical slice (`card-storage-mvp`, archived) and now exposes `GET /cards/{scryfall_id}` over HTTP — the first real cross-context HTTP route in the platform. The `service-topology` spec already declares the `cortex → lexicon` edge, but the **shape** of what passes over that edge (path, payload, error format) has no contract in `rbrain-codex`. As long as the contract lives only in `rbrain-lexicon`'s internal `card-storage` spec, `rbrain-cortex` has no authoritative reference to consume when it wires the lookup as an agent tool, and any drift on the lexicon side ships silently.

This change closes the loop by introducing the first **per-sibling public-API capability** in `rbrain-codex`: `lexicon-api`. The scope is intentionally narrow — only what lexicon ships today (one endpoint) — so the spec reflects reality, not aspiration. Future endpoints (search, list-by-set) land as MODIFIED deltas on this same capability when lexicon implements them.

## What Changes

- Introduce a new capability `lexicon-api` in `rbrain-codex` whose scope is the HTTP contract `rbrain-lexicon` exposes to in-cluster callers (today: `rbrain-cortex` via the `cortex → lexicon` edge in `sync-graph.yaml`).
- The capability defines exactly one endpoint at v1: `GET /cards/{scryfall_id}`.
- The capability defines the `Card` payload shape (six fields, all strings) and the `404` error shape (`error`, `scryfall_id`).
- Establish the convention that **per-sibling public-API capabilities follow the pattern `<context>-api`** in codex. `oracle-api`, `forge-api`, etc. land the same way when their sibling ships its first endpoint.
- No script and no validator code in codex. The contract is enforced by lexicon's CI (which already runs `validate-repo.sh`) and by cortex's CI (which will fail when its mock client drifts from the contract). Adding a codex-side HTTP contract validator is a future change.

## Capabilities

### New Capabilities

- `lexicon-api`: HTTP contract for `rbrain-lexicon`'s public surface. v1 declares one endpoint and one payload shape. The capability owner is `rbrain-lexicon`; consumers (currently `rbrain-cortex`) reference it when implementing client code or agent tools.

### Modified Capabilities

None.

## Impact

- **`rbrain-codex` repo layout**: new `openspec/specs/lexicon-api/spec.md` once this change archives. No script, no YAML, no CI step added.
- **`rbrain-lexicon`**: no change required. The contract reflects the slice already shipped and verified in CI. A future MODIFIED delta against `lexicon-api` may add endpoints that lexicon must then implement — that's the normal forward flow.
- **`rbrain-cortex`** (when it ships its first capability): consumes this spec when wiring the `lookup_card` agent tool.
- **Convention spillover**: this is the first per-sibling `<context>-api` capability. The pattern documented here (proposal naming, capability scope, where the spec lives) sets the template for the remaining seven public-facing siblings.
- **Out of scope (non-goals)**:
  - Endpoints that lexicon does not yet ship (`/cards`, search, list-by-set, batch lookup).
  - NATS event subjects (`rbrain.lexicon.card-released`, `rbrain.lexicon.catalogue-rebuilt`) — they will be added when lexicon's sync slice publishes them.
  - OpenAPI document generation or schema-from-code tooling.
  - Codex-side validators that diff lexicon's actual responses against the spec.
  - Cortex-side mock or contract testing.
