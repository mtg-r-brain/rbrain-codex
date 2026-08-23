# Tasks — consumer-tolerance-convention

Spec-only change. No sibling code ships here; each consumer's
`extra="forbid"` → `extra="ignore"` move is a per-repo change of its own.

## 1. Apply the delta

- [x] `openspec new change consumer-tolerance-convention` + write `proposal.md`, `design.md`, `tasks.md`
- [x] Write the `repository-conventions` delta: widen the closure clause to response shapes / request bodies / query parameters, add the "Consumer tolerance of additive response fields" requirement
- [x] Write the `forge-api` delta: the tolerance requirement references `repository-conventions` as the authoritative source, drops the "not in its scope" note
- [x] `openspec validate consumer-tolerance-convention --strict` green
- [x] Confirm no other codex source is implicated — no `catalog.yaml`, `sync-graph.yaml`, `runtime-allocation.yaml` or `memory-budgets.yaml` edit, therefore no `refresh-baselines.sh` run and no sibling `OWNERSHIP.yaml` knock-on

## 2. Promote and archive

- [x] Commit `📝 propose(consumer-tolerance-convention)`
- [x] Promote the deltas into `openspec/specs/repository-conventions/spec.md` and `openspec/specs/forge-api/spec.md`; commit `🔄 sync(consumer-tolerance-convention)`
- [x] Archive with `openspec archive consumer-tolerance-convention -y --skip-specs` (the sync already promoted the deltas, so the archive only relocates the change), commit `📦 archive(consumer-tolerance-convention)`
- [x] Verify the promoted specs read coherently end to end (no duplicated requirement, no orphaned scenario)
- [x] Push; CI green

## 3. Hand off

- [x] Record in the handoff drawer that the consumer-tolerance rule is now platform-wide, closing the follow-up named by `forge-api-response-shape-catchup`
- [x] Note the remaining follow-ups: the six other `<context>-api` capabilities' local tolerance pointers (design.md Open Questions), and the per-consumer `extra="ignore"` remediation audits
