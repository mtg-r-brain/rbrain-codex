# Tasks — forge-api-response-schema

## 1. Verify before documenting

- [x] Confirm `validate-response-shapes.sh` self mode green in codex (`context=codex, 8 routes, spec lockstep green`) before writing this change
- [x] Confirm sibling mode green against `rbrain-forge` (`context=forge, 8 routes`) — the router extraction handles Axum's multi-line `.route(` and normalizes `:id`→`{id}`
- [x] Confirm runtime mode green against a live forge (`FORGE_URL`) for the three stateless routes, and that the yq expressions use `all_c`/YAML tags correctly on real payloads
- [x] Confirm the negative cases fail loudly: a route added and a route removed both diverge with named missing/extra sets

## 2. Codex artifacts (feat)

- [x] `openspec/specs/forge-api/schema.yaml` — components + routes, grammar documented in header
- [x] `scripts/validate-response-shapes.sh` — self + sibling + opt-in runtime modes
- [x] `.github/workflows/ci.yml` — `Validate response shapes` step in the validate job

## 3. Apply the deltas (sync)

- [ ] ADDED requirement header matches the canonical spec's section format (`### Requirement:` under `## ADDED Requirements`)
- [ ] `openspec archive forge-api-response-schema -y`
- [ ] Verify the promoted spec: the machine-readability requirement present in `forge-api/spec.md`, no duplicated requirement, no orphaned scenario
- [ ] `bash scripts/validate-response-shapes.sh` green (self mode — meaningful only after promotion)
- [ ] `bash scripts/validate-response-shapes.sh ../rbrain-forge` green (sibling mode)
- [ ] `bash scripts/validate-repo.sh .` and the other codex validators still green
- [ ] Stage the sync commit with an explicit path list (`openspec/specs/forge-api/spec.md`) — never `git add -A openspec/`

## 4. Forge sibling wiring (chore commit, no OpenSpec change of its own)

- [ ] forge CI: `bash .codex/scripts/validate-response-shapes.sh .` after the existing validate steps
- [ ] Confirm forge CI green with the new step

## 5. Hand off

- [ ] Record that the schema's runtime mode is opt-in by design: the persistence routes are out of scope (they need `X-User-Id` and a database)
- [ ] Record the ordering dependency: sibling mode on forge is meaningful only once forge's router matches the schema, which it does today — the gate is green before it is wired
