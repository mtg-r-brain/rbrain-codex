## 1. Canonical spec (rbrain-codex)

- [ ] 1.1 ADDED requirement "Canonical local-development port map" in `service-topology` (this change's spec delta).

## 2. Fix .env.example — rbrain-gateway (the broken one)

- [ ] 2.1 `rbrain-gateway/.env.example`: `IDENTITY_URL=http://localhost:8083`, `CORTEX_URL=http://localhost:8081`, `LEXICON_URL=http://localhost:8080`, `ORACLE_URL=http://localhost:8082`, `PORT=8090`. Update the stale comments.

## 3. Fix .env.example — rbrain-cortex (missing required NATS_URL)

- [ ] 3.1 `rbrain-cortex/.env.example`: add required `NATS_URL=nats://localhost:4224` (cortex exits 78 at boot without it); note the HTTP port is `8081` (`uvicorn --port 8081`).

## 4. Add HTTP-port notes — lexicon / oracle / identity

- [ ] 4.1 `rbrain-lexicon/.env.example`: note HTTP port `8080`.
- [ ] 4.2 `rbrain-oracle/.env.example`: confirm HTTP port note reads `8082` (already present as a comment).
- [ ] 4.3 `rbrain-identity/.env.example`: confirm HTTP port note reads `8083` (already present as a comment).
- [ ] 4.4 `rbrain-app/.env.example`: already correct (`NEXT_PUBLIC_GATEWAY_URL=8090`) — no change.

## 5. Verify

- [ ] 5.1 Each edited `.env.example` matches the canonical table.
- [ ] 5.2 `openspec validate port-mapping-convention --strict` passes (codex).

## 6. CI + archive

- [ ] 6.1 Push planning commits (codex).
- [ ] 6.2 Push the cross-repo `.env.example` edits (gateway, cortex, lexicon).
- [ ] 6.3 Archive (`openspec archive` + `git add -A openspec/`) to `openspec/changes/archive/2026-06-16-port-mapping-convention/`, promote canonical spec (codex).
- [ ] 6.4 Push the archive commit (codex).
