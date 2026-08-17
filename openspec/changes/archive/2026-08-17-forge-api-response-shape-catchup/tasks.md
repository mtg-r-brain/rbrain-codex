# Tasks — forge-api-response-shape-catchup

Spec-only change. No forge, cortex, or app code ships here; the consumer-side
`extra="ignore"` move is the next slice, in `rbrain-cortex`.

## 1. Verify the drift before documenting it

- [x] Re-read `rbrain-forge/src/store.rs::StoredDeck` and confirm the twelve serialized fields match the payload table in the delta, field name for field name
- [x] Re-read `rbrain-forge/src/handlers.rs::parse_format_field` / `parse_status_field` and confirm the accepted values and the `422` messages match what the delta claims
- [x] Confirm `DeckSummary` still carries exactly four fields, so `GET /decks` genuinely needs no change
- [x] Confirm `GET /decks/{id}?version=N` rejects a non-positive `N` with `422` and an out-of-range `N` with `404`, per `handlers.rs::get_deck`
- [x] Confirm the sixteen `format` identifiers written into the delta match `rbrain-forge/src/legality_store.rs::FORMATS` exactly, string for string — the delta enumerates them rather than referencing a sibling-local spec (design.md Decision 1), so a typo here is a contract defect

## 2. Apply the delta

- [x] `bash scripts/validate-repo.sh .` green
- [x] Confirm no other codex source is implicated — no `catalog.yaml`, `sync-graph.yaml`, `runtime-allocation.yaml` or `memory-budgets.yaml` edit, therefore no `refresh-baselines.sh` run and no sibling `OWNERSHIP.yaml` knock-on
- [x] Archive with `openspec archive forge-api-response-shape-catchup -y`, promoting the delta into `openspec/specs/forge-api/spec.md`
- [x] Verify the three MODIFIED requirement headers matched verbatim and the promoted spec reads coherently end to end (no duplicated requirement, no orphaned scenario)

## 3. Hand off to the next slice

- [x] Record in the handoff drawer that the contract baseline is now true, so the `errors` delta is written against it rather than against the 2026-07-06 text
- [x] Record the three follow-ups this change names but does not do: a `validate-response-shapes.sh` validator (needs a machine-readable schema — see design.md Open Questions), promoting the consumer-tolerance requirement to `repository-conventions` across the six other `<context>-api` capabilities, and hoisting the sixteen-format whitelist into a single platform-level source in codex consumed by both lexicon and forge (design.md Decision 1)
