## 1. Contract (rbrain-codex)

- [ ] 1.1 deployment-stack: ADD single compose entry point, shared PostgreSQL provisioned from `postgres-roles.yaml`, shared NATS JetStream, sibling-checkout builds, complete internal wiring, secrets discipline, canonical host ports (+ infra 5440/4240), health-gated ordering, budget-derived memory limits, ten-container composition closure.
- [ ] 1.2 `openspec validate deploy-compose-stack --strict` passes.

## 2. Archive

- [ ] 2.1 Push planning commit.
- [ ] 2.2 Archive + `git add -A openspec/`; promote canonical `deployment-stack`.
- [ ] 2.3 Push the archive commit.

## 3. Implementation (rbrain-deploy — hand-scaffolded sibling)

- [ ] 3.1 Materialize the repo: `OWNERSHIP.yaml` (`runtime: none`, `max_rss_mb: 0`, empty `depends_on`/`publishes`), conformant `AGENTS.md`, `README.md`, `.gitignore` (`.env`), `openspec/` init.
- [ ] 3.2 `scripts/gen-postgres-init.sh`: derive `postgres/init/*.sql` from codex `postgres-roles.yaml` (extension, roles, schemas with `AUTHORIZATION`, `search_path`); check in the generated SQL.
- [ ] 3.3 `docker-compose.yaml`: `postgres` (pgvector/pgvector:pg16, host 5440, init mount, 256 MB), `nats` (2.10-alpine, `-js` + file store, host 4240/8240, 40 MB), eight services built from `../rbrain-<ctx>` with full env wiring, canonical HTTP host ports, healthchecks, `depends_on: service_healthy`, budget memory limits.
- [ ] 3.4 `.env.example`: `JWT_SECRET`, `LLM_PROVIDER` + provider blocks (mirroring cortex's), optional OAuth block; placeholders only.
- [ ] 3.5 CI: fetched `validate-repo.sh`, `docker compose config` with example env, generator-drift check (regenerate + diff).
- [ ] 3.6 Sibling openspec change `compose-stack-mvp` (spec + tasks) documenting the implementation; archive after apply.

## 4. Publish

- [ ] 4.1 Create `mtg-r-brain/rbrain-deploy` (private) and push.

## 5. First-build validation

- [ ] 5.1 `docker compose config` green locally.
- [ ] 5.2 `docker compose build` attempted; fix expected sibling drift as chores in the owning repos (Rust base image vs 1.88 floor on gateway/identity/oracle/lexicon; `ARG NEXT_PUBLIC_GATEWAY_URL` + invalid `COPY … || true` in rbrain-app).
- [ ] 5.3 Full `up -d` + health sweep is deliberately NOT gated here — it is the opening move of the live smoke batch (queue step 2).
