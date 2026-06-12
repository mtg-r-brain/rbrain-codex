## 1. Spec authorship

- [x] 1.1 Draft `cortex-api` ADDED requirements covering: POST /chat route + caller invariant; request body shape (`message`, `conversation_id?`); response body shape (`response`, `conversation_id`, `tool_calls`, `finish_reason` discipline); `tool_calls` trace entry shape; closure clause on the public route set with explicit `/admin/*` non-allowance for v1
- [x] 1.2 Ensure each requirement carries ≥1 WHEN/THEN scenario; cover happy path, edge cases (empty message, extra fields, unknown conversation_id, budget_exhausted reservation, provider passthrough, ordering, error observation passthrough)
- [x] 1.3 Cross-reference `repository-conventions` for `/health` and `lexicon-api-admin-carveout` as the carve-out precedent (do not duplicate either)

## 2. Faithfulness to cortex's current behaviour

- [x] 2.1 Verify request shape matches `rbrain-cortex/app/chat/types.py::ChatRequest` (extra forbidden, message min_length=1, conversation_id optional null)
- [x] 2.2 Verify response shape matches `rbrain-cortex/app/chat/types.py::ChatResponse` (extra forbidden, four fields)
- [x] 2.3 Verify trace-entry shape matches `rbrain-cortex/app/chat/types.py::ToolCallTrace` (extra forbidden, three fields)
- [x] 2.4 Verify `budget_exhausted` literal matches `rbrain-cortex/app/agent/loop.py` (the return path after MAX_ITERATIONS)
- [x] 2.5 Verify the gateway → cortex edge exists in `service-topology/sync-graph.yaml` (no MODIFIED needed)

## 3. Validation

- [x] 3.1 `openspec validate cortex-api --strict` clean (no warnings)
- [x] 3.2 `openspec status --change cortex-api --json` reports `isComplete: true` after artifacts are in place
- [x] 3.3 No existing codex capability spec needs a MODIFIED delta (audited against: bounded-contexts, service-topology, repository-conventions, llm-abstraction, data-stores, lexicon-api, scaffold-templates, scaffold-procedure)

## 4. CI and archive

- [x] 4.1 Push the 4 planning commits; verify the codex CI workflow (7 validators + scaffold-drift) goes green
- [x] 4.2 Run `/opsx:archive cortex-api` to promote the delta into `openspec/specs/cortex-api/spec.md`
- [ ] 4.3 Push the archive commit; verify CI stays green
- [ ] 4.4 Update the platform handoff drawer in MemPalace (`mempalace_update_drawer` on `rbrain-codex/task-handoff`) marking ticket #2 done; re-list remaining queued tickets
