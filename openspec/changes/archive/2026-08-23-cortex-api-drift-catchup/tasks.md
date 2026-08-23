# Tasks — cortex-api-drift-catchup

Spec-only change. No cortex code ships here; the contract is brought level with
what cortex already serves.

## 1. Verify the drift before documenting it

- [x] Re-read `rbrain-cortex/app/decks/router.py` and confirm the `deck` object of `GET /decks/{deck_id}/analysis` carries exactly `id`, `name`, `format`, `format_violations` in both the empty-mainboard and the composed paths
- [x] Re-read `rbrain-cortex/app/forge/types.py` and confirm `format` is `str | None` and `format_violations` is a `{name, status}` list, possibly empty
- [x] Confirm `analysis` still carries exactly the six forge fields, so the delta touches only the `deck` object
- [x] Confirm the route set is unchanged (three paths), so the closure requirement needs no edit

## 2. Apply the delta

- [x] Write the `cortex-api` delta: MODIFIED "Deck analysis composition endpoint" — `deck` widened to `{id, name, format, format_violations}`, round-trip scenario widened
- [x] `openspec validate cortex-api-drift-catchup --strict` green
- [x] Confirm no other codex source is implicated — no `catalog.yaml`, `sync-graph.yaml`, `runtime-allocation.yaml` or `memory-budgets.yaml` edit, therefore no `refresh-baselines.sh` run and no sibling `OWNERSHIP.yaml` knock-on
- [x] Commit `📝 propose(cortex-api-drift-catchup)`
- [x] Promote the delta into `openspec/specs/cortex-api/spec.md`; commit `🔄 sync(cortex-api-drift-catchup)`
- [x] Archive with `openspec archive cortex-api-drift-catchup -y --skip-specs` (the sync already promoted the delta, so the archive only relocates the change), commit `📦 archive(cortex-api-drift-catchup)`
- [x] Verify the promoted spec reads coherently end to end (no duplicated requirement, no orphaned scenario)
- [x] Push; CI green

## 3. Hand off

- [x] Record in the handoff drawer that the cortex-api contract baseline is now true, closing the drift documented by `cortex-deck-format` and `forge-payload-tolerance` in the cortex capability
- [x] Note the remaining follow-ups: the `validate-response-shapes.sh` validator (needs a machine-readable schema), and the per-consumer `extra="ignore"` remediation audits
