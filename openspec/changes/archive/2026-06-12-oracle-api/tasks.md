## 1. Spec authorship

- [x] 1.1 Draft 4 ADDED requirements: route + 200 shape + 404 shape + closure clause
- [x] 1.2 Scenarios cover: cortex caller, opaque path param, example 200, extra fields forbidden, all-strings, unknown returns 404, empty number, MODIFIED-required for new routes, /health out of scope, admin requires carve-out
- [x] 1.3 `openspec validate oracle-api --strict` clean

## 2. CI and archive

- [x] 2.1 Push the 4 planning commits; verify codex CI workflow goes green (8 validators including the new validate-api-closure.sh — which SHALL pass since the closure clause is in scenario form)
- [x] 2.2 Run `/opsx:archive oracle-api` to promote the ADDED delta into `openspec/specs/oracle-api/spec.md`
- [x] 2.3 Push the archive commit; verify codex CI stays green

## 3. Companion implementation

- [ ] 3.1 Track in the rbrain-oracle repo as `oracle-rules-storage-mvp` (separate OpenSpec change in that repo). Implementation includes: sqlx + migration 0001 (oracle.rules table), Rule struct + RuleStore trait + Postgres impl + InMemory impl, GET /rules/{number} handler, seed rule 100.1, docker-compose.yaml local PG, CI workflow update, integration test
