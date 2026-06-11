## Why

`rbrain-lexicon`'s next slice (`scryfall-sync`) needs to expose a `POST /admin/sync` endpoint to trigger ingestion of Scryfall's bulk catalogue. The `lexicon-api` capability in codex currently asserts that lexicon SHALL expose **exactly two HTTP routes** (`/health` and `/cards/{scryfall_id}`); shipping `/admin/sync` without a contract amendment would put the running service in violation of the live spec.

The amendment is small but semantically meaningful: the `lexicon-api` capability captures the **public** cross-context surface (what `rbrain-cortex` and friends call), not platform-internal operator endpoints. Carving `/admin/*` out of the contract makes that distinction explicit and unblocks slice 3 without enshrining the admin endpoint as part of the cross-context API.

## What Changes

- Amend `lexicon-api`'s "No other HTTP routes at v1" requirement to scope the carve to **public** routes only.
- Reserve the `/admin/*` path prefix for operator/internal endpoints that the `lexicon-api` contract does not cover.
- Document that endpoints under `/admin/*` MUST NOT be reachable through `rbrain-gateway` (the public ingress). Gateway routing rules will enforce this when gateway ships; in the meantime, lexicon is internal-only per `service-topology`, so the only callers are inside the cluster.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lexicon-api`: amend the requirement that constrains the set of HTTP routes to clarify it applies to public routes; introduce the `/admin/*` carve-out as a parallel scenario.

## Impact

- **`rbrain-codex`**: one MODIFIED delta in `lexicon-api`'s spec. No script, no validator change.
- **`rbrain-lexicon`** (downstream): the `scryfall-sync` change can now ship `/admin/sync` without violating the cross-context contract.
- **`rbrain-gateway`** (future): when gateway lands, its routing rules MUST reject `/admin/*` requests from external callers. The contract here makes that explicit.
- **Out of scope**:
  - Defining the shape of any specific `/admin/*` endpoint (`/admin/sync` is shaped in lexicon's own spec).
  - Auth on `/admin/*` (no auth in v1; gateway-side enforcement is the v1 protection).
  - Promoting any `/admin/*` endpoint to public surface (would require a new MODIFIED).
