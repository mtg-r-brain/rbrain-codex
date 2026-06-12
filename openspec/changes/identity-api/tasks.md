## 1. Spec authorship

- [x] 1.1 Draft 5 ADDED requirements: register route, register request/response shapes, login route + login request/response shapes, JWT claims contract, closure clause
- [x] 1.2 Each requirement carries ≥1 scenario; cover happy path, duplicate email, malformed email, short password, wrong credentials, JWT claims shape, HS256 algorithm, MODIFIED-required for new routes, /health out of scope, admin requires carve-out
- [x] 1.3 `openspec validate identity-api --strict` clean

## 2. CI and archive

- [ ] 2.1 Push the 4 planning commits; verify codex CI workflow goes green (8 validators + scaffold-drift + the new validate-baselines.sh; validate-api-closure.sh picks up the new capability automatically)
- [ ] 2.2 Run `/opsx:archive identity-api` to promote the ADDED delta into `openspec/specs/identity-api/spec.md`
- [ ] 2.3 Push the archive commit; verify codex CI stays green

## 3. Companion implementation

- [ ] 3.1 Track in the rbrain-identity repo as `identity-bootstrap-mvp` (separate OpenSpec change). Implementation: sqlx + Postgres `identity.users` table, argon2 password hashing, jsonwebtoken for HS256, handlers, env vars `DATABASE_URL` + `JWT_SECRET`, docker-compose with PG on host port 5435 (distinct from lexicon/cortex/oracle ports)
