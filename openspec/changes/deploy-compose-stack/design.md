# deploy-compose-stack — Design

## D1. Single shared PostgreSQL, not the six per-repo instances

Local development grew one Postgres container per repo (host ports 5432–5437). That topology is a dev convenience, not the contract: `data-stores` requires "a single shared PostgreSQL 16 instance with the `pgvector` extension". The stack follows the spec.

- **Image**: `pgvector/pgvector:pg16` (the stock `postgres:16` image does not ship pgvector, and `postgres-baseline.md` mandates `CREATE EXTENSION vector` at server bootstrap, not lazily).
- **One database** (`rbrain`), six schemas, six roles per `postgres-roles.yaml`.
- **Schema ownership**: `CREATE SCHEMA <ctx> AUTHORIZATION <ctx>`. Ownership gives each role `USAGE` + `CREATE` on its own schema and full DML on the relations it creates — exactly what boot-time migrations (SQLx/Alembic) need, while cross-schema access still fails at the database layer. This is the literal reading of `postgres-baseline.md` ("each role owns exactly one schema").
- **`search_path`**: `ALTER ROLE <ctx> SET search_path = <ctx>` so unqualified migrations (written against the per-repo dev databases, where everything landed in `public`) create their tables in the owning schema without modification.
- **Derived SQL**: the init script is **generated** from `postgres-roles.yaml` by a checked-in generator in `rbrain-deploy` (`postgres-roles.yaml` is the contract; the SQL is the derived artefact — `postgres-baseline.md`'s words). CI regenerates and diffs to catch drift.
- **Dev-parity credentials** (`role == password`) as defaults, overridable via environment. A local stack is not a production posture; Helm (v2) will do secrets properly.

Rejected alternative: mirror the six dev Postgres containers into the stack. Zero migration risk, but it would ship a deployment artifact that contradicts a committed platform requirement on day one, and would waste ~5 × the Postgres baseline RSS against a 1024 MB ceiling.

## D2. Single NATS JetStream broker

Per-repo dev runs up to four NATS instances (4222–4225), with cortex pointing at identity's. `messaging-runtime` prescribes one broker; the `rbrain.<ctx>.*` subject namespacing exists precisely so contexts can share it. The stack runs one `nats:2.10-alpine` with `-js` and file storage. Services keep creating their own streams at boot (stream names — `IDENTITY_EVENTS`, `ORACLE_RULES`, … — are already distinct). `jetstream-policy.yaml` defaults apply.

## D3. Redis is omitted at v1

`data-stores` declares Redis the sole cache layer *for services that need a cache*. No service consumes Redis today. Including it would burn 50 MB of the memory ceiling and one container for zero consumers. The composition-closure requirement makes the omission explicit and auditable; the first sibling change that introduces a Redis consumer MUST also amend `deployment-stack` to add the container.

## D4. Services build from sibling checkouts

No image registry exists, and the platform's working mode is nine sibling clones under one parent directory. Each service is declared with `build.context: ../rbrain-<ctx>`, using the sibling's own `Dockerfile` (every runtime sibling already ships one from its scaffold). A registry + pinned image digests belong to the Helm/production story (v2).

Known drift expected at first build, to be fixed as sibling chores (not in this change):

- Rust Dockerfiles pin `rust:1.83-slim`, but gateway/identity/oracle/lexicon compile on the 1.88 floor (edition2024 transitive deps) and the Dockerfiles do not `COPY rust-toolchain.toml`.
- `rbrain-app`'s Dockerfile has no `ARG NEXT_PUBLIC_GATEWAY_URL` (the value is inlined at `pnpm build` time), and its `COPY … || true` line is not valid Dockerfile syntax.

## D5. Host ports: canonical HTTP map, dedicated infra ports

- **HTTP**: the stack exposes each service on the canonical local-dev port map (`service-topology`): lexicon 8080, cortex 8081, oracle 8082, identity 8083, chronicle 8084, forge 8085, gateway 8090, app 3000. Operators and the recorded smoke recipes keep working unchanged; chronicle's reserved 8084 becomes live.
- **Infrastructure**: Postgres on host **5440**, NATS on host **4240** (+ 8240 monitoring). These deliberately avoid 5432–5437/4222–4225 so the platform stack can coexist with any per-repo dev stack. Inside the compose network the canonical container ports (5432, 4222) apply, and services address each other by service name (`http://gateway:8080`, `postgres:5432`, `nats:4222`) — never `localhost`.

## D6. rbrain-deploy is hand-scaffolded

`scaffold-procedure` makes the scaffolder reject `runtime: none` contexts, by design. Like codex, rbrain-deploy is materialized by hand but conforms to `repository-conventions`: `OWNERSHIP.yaml` (`runtime: none`, `max_rss_mb: 0`, `depends_on: []`, `publishes: []`), a conformant `AGENTS.md`, its own `openspec/` for implementation-level capabilities, and CI running the fetched `validate-repo.sh` plus `docker compose config` and generator-drift checks. `rbrain.system.*` stays reserved and **unused** at v1 — deploy declares no publishes until a control-plane feature actually ships.

## D7. Memory limits are declared, observations feed back via OpenSpec

Every container carries a memory limit derived from `memory-budgets.yaml` (services) and its `external:` block (postgres 256, nats 40). Frugality (~1 GB single-node ceiling) is a founding platform constraint; the stack is where it becomes measurable. If a service OOMs under a real workload, that is a signal to revise the budget — through an OpenSpec change on `memory-budgets.yaml`, not by silently raising the compose limit.
