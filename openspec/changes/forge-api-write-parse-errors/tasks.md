# Tasks — forge-api-write-parse-errors

Spec-only change. The forge implementation is the next slice.

## 1. Verify before documenting

- [x] Confirm `rbrain-forge/src/deck.rs::ParseError` is `{line, content, reason}` with `line` 1-based, so the delta's shape claim matches the producer
- [x] Confirm `POST /decks/parse` already returns that array (`handlers.rs::parse_deck` serializes the whole `ParsedDeck`), so the delta reuses a shipped shape rather than inventing one
- [x] Confirm `forge-deck-parsing` states that parsing never fails the request, so Decision 3 restates an existing stance rather than introducing one
- [x] Confirm `rbrain-cortex`'s `StoredDeck` already declares `errors` with an empty-list default, so the delta's "either rollout order" claim in the proposal is true

## 2. Apply the delta

- [x] Both MODIFIED requirement headers match the canonical spec verbatim
- [x] `bash scripts/validate-repo.sh .` green
- [x] No `catalog.yaml`, `sync-graph.yaml`, `runtime-allocation.yaml` or `memory-budgets.yaml` edit, therefore no `refresh-baselines.sh` and no sibling `OWNERSHIP.yaml` knock-on
- [ ] Archive with `openspec archive forge-api-write-parse-errors -y`
- [ ] Verify the promoted spec: `errors` in the payload table, the request-scoped paragraph and the read-side ambiguity warning present, no duplicated requirement, no orphaned scenario
- [ ] Stage the sync commit with an explicit path list (`openspec/specs/forge-api/spec.md`) — a `git add -A openspec/` sweeps the archive move into the sync commit and conflates the two lifecycle stages

## 3. Hand off

- [ ] Record that the forge slice grafts `parsed.errors` onto the returned payload in the handler, leaving `DeckStore` untouched — no migration, the field is never persisted
- [ ] Record the interim observability gap: until the app slice stops blocking submission client-side, this field reads as always-empty from the app's own path, which must not be mistaken for a broken implementation
- [ ] Record the open question: whether `POST /decks/analyze` should gain the same field
