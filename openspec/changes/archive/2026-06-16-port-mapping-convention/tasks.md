## 1. Canonical spec (rbrain-codex)

- [x] 1.1 ADDED requirement "Canonical local-development port map" in `service-topology`.

## 2. Fix .env.example — rbrain-gateway (the broken one)

- [x] 2.1 `rbrain-gateway/.env.example`: `IDENTITY_URL=8083`, `CORTEX_URL=8081`, `LEXICON_URL=8080`, `ORACLE_URL=8082`, `PORT=8090`; comments rewritten. Pushed (gateway 42da47c..590989c).

## 3. Fix .env.example — rbrain-cortex (missing required NATS_URL)

- [x] 3.1 `rbrain-cortex/.env.example`: added required `NATS_URL=nats://localhost:4224` (boot exits 78 without it) + HTTP port 8081 note. Pushed (cortex 72a3d1b..5962683).

## 4. Add HTTP-port notes — lexicon / oracle / identity

- [x] 4.1 `rbrain-lexicon/.env.example`: HTTP port 8080 note. Pushed (lexicon a4a75ec..2023838).
- [x] 4.2 `rbrain-oracle/.env.example`: HTTP port 8082 reference. Pushed (oracle ad751f4..d5f2e1e).
- [x] 4.3 `rbrain-identity/.env.example`: HTTP port 8083 reference. Pushed (identity 0a5c4ec..6a11757).
- [x] 4.4 `rbrain-app/.env.example`: already correct (`NEXT_PUBLIC_GATEWAY_URL=8090`) — no change.

## 5. Verify

- [x] 5.1 Each edited `.env.example` matches the canonical table.
- [x] 5.2 `openspec validate port-mapping-convention --strict` passes.

## 6. CI + archive

- [x] 6.1 Push planning commits (codex).
- [x] 6.2 Push the cross-repo `.env.example` edits (gateway, cortex, lexicon, oracle, identity).
- [x] 6.3 Archive (`openspec archive` + `git add -A openspec/`) to `openspec/changes/archive/2026-06-16-port-mapping-convention/`, promote canonical spec (codex).
- [x] 6.4 Push the archive commit (codex).
