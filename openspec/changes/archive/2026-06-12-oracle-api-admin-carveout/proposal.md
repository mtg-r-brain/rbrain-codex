## Why

`oracle-api` v1 forbids `/admin/*` routes outright. The next slice (`comprehensive-rules-sync` in rbrain-oracle) needs `POST /admin/sync` to trigger a fetch+parse+upsert of WotC's Comprehensive Rules `.txt` file — exactly the same operator-only pattern lexicon shipped with `scryfall-sync` and its `/admin/*` carve-out (archived 2026-06-11).

This change carves `/admin/*` out of oracle's closure clause, mirroring `lexicon-api-admin-carveout` verbatim. Once it ships, the oracle implementation can land `POST /admin/sync { rules_url }` without touching codex again.

## What Changes

- MODIFY `oracle-api` requirement "No other public HTTP routes at v1" to:
  - Allow `/admin/*` as operator/platform-internal routes whose existence does NOT require a MODIFIED on `oracle-api`.
  - State that `/admin/*` routes SHALL NOT be reachable through `rbrain-gateway` once gateway routing ships (gateway ingress rules reject any external path matching `^/admin/`).
  - Until gateway exists, oracle's internal-only status (per `service-topology`'s sync graph) is the implicit protection.
- The per-endpoint shape of each `/admin/*` route lives in the consuming sibling's capability spec (e.g. `comprehensive-rules-sync`'s `POST /admin/sync` will live in `rbrain-oracle/openspec/specs/comprehensive-rules-sync/spec.md`).

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `oracle-api`: MODIFIED requirement "No other public HTTP routes at v1" — adds the `/admin/*` carve-out paragraph and the gateway-rejection clause; removes the "SHALL NOT expose any /admin/*" prohibition.

## Impact

- **Code**: none. Implementation lives in the oracle repo's follow-up `comprehensive-rules-sync` change.
- **APIs**: no wire change yet — this is the gate that lets the next slice land.
- **Specs touched**: codex `oracle-api` only.
- **Validators**: `validate-api-closure.sh` still passes — the canonical "SHALL expose exactly two **public** HTTP routes" phrasing stays intact; the carve-out is appended below.
- **Migration**: none.
