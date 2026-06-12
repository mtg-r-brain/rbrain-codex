## 1. Spec authorship

- [x] 1.1 Draft 4 ADDED requirements: identity proxy (unauthenticated), protected proxy (JWT-required), X-User-Id forwarding, closure clause.
- [x] 1.2 Each requirement carries ≥2 scenarios covering happy path + anti-enumeration + edge cases.
- [x] 1.3 `openspec validate gateway-api --strict` clean.

## 2. CI and archive

- [ ] 2.1 Push the 4 planning commits; verify codex CI workflow goes green (9 validators including validate-api-closure picks up the new capability automatically).
- [ ] 2.2 Run `/opsx:archive gateway-api` to promote the ADDED delta.
- [ ] 2.3 Push the archive commit; verify codex CI stays green.

## 3. Companion implementation

- [ ] 3.1 Track in rbrain-gateway repo as `gateway-bootstrap-mvp`. Stack: reqwest + axum + jsonwebtoken + bytes proxy. Env: JWT_SECRET, IDENTITY_URL, CORTEX_URL, LEXICON_URL, ORACLE_URL, PORT (default 8080).
