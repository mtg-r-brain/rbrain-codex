# deployment-stack Specification

## Purpose
TBD - created by archiving change deploy-compose-stack. Update Purpose after archive.
## Requirements
### Requirement: Single docker compose entry point

`rbrain-deploy` SHALL ship a single `docker-compose.yaml` at its repository root that brings up the entire platform — shared infrastructure and all eight runtime services — with one command (`docker compose up -d`) executed from a checkout sitting alongside the sibling repositories. No other bring-up path (per-repo composes, manual `cargo run` chains) SHALL be required for a full-platform run.

#### Scenario: One command brings the platform up

- **WHEN** an operator with the nine sibling repos cloned under a common parent runs `docker compose up -d` in `rbrain-deploy` with a populated `.env`
- **THEN** the stack SHALL start shared PostgreSQL, shared NATS, and the eight runtime services, and every service's `GET /health` SHALL return the canonical payload once the stack is settled

#### Scenario: Compose file validates

- **WHEN** CI runs `docker compose config` against the repository's `docker-compose.yaml` with the example environment
- **THEN** the command SHALL exit zero

### Requirement: Single shared PostgreSQL instance provisioned from postgres-roles.yaml

The stack SHALL run exactly one PostgreSQL container, version `>= 16.0` with the `pgvector` extension available, hosting one database (`rbrain`) with the six per-context schemas and roles declared in `data-stores/postgres-roles.yaml`. Provisioning SHALL be applied by Postgres init scripts **generated** from `postgres-roles.yaml` by a checked-in generator script in `rbrain-deploy`; the YAML is the contract and the SQL is the derived artefact. The init scripts SHALL: activate `CREATE EXTENSION IF NOT EXISTS vector`; create each role without superuser; create each schema with `AUTHORIZATION` its owning role; and set each role's default `search_path` to its own schema. Cross-schema access SHALL fail at the database layer.

#### Scenario: Generated SQL tracks the roles contract

- **WHEN** an entry is added to or modified in `postgres-roles.yaml` and the generator is re-run
- **THEN** the regenerated init SQL SHALL reflect the change, and CI SHALL fail if the checked-in SQL differs from a fresh generation

#### Scenario: pgvector is active at bootstrap

- **WHEN** the PostgreSQL container completes first-time initialization
- **THEN** `SELECT extname FROM pg_extension` SHALL include `vector` without any service having connected

#### Scenario: Migrations land in the owning schema

- **WHEN** `rbrain-identity` boots against the stack DSN and applies its SQLx migrations
- **THEN** its tables SHALL be created in the `identity` schema (via the role's `search_path`), not in `public`

#### Scenario: Cross-schema read is blocked

- **WHEN** a connection authenticated as the `oracle` role executes `SELECT` on a relation in the `forge` schema
- **THEN** PostgreSQL SHALL return a permission-denied error

### Requirement: Single shared NATS JetStream broker

The stack SHALL run exactly one NATS container, version `>= 2.10`, started with JetStream enabled and file-backed storage, serving every event-publishing or event-consuming service. Per-repo development brokers SHALL NOT appear in the stack. Stream and consumer configuration SHALL follow `messaging-runtime/jetstream-policy.yaml` defaults.

#### Scenario: All contexts share the broker

- **WHEN** identity publishes `rbrain.identity.user-registered` and cortex's consumer is attached to the stack's NATS URL
- **THEN** cortex SHALL receive the event through the single broker without any cross-instance bridging

#### Scenario: JetStream is verified at startup

- **WHEN** the NATS container's healthcheck runs
- **THEN** it SHALL only report healthy if the server is up with JetStream enabled

### Requirement: Services build from sibling checkouts

The stack SHALL define one service per runtime bounded context — `gateway`, `identity`, `lexicon`, `oracle`, `forge`, `chronicle`, `cortex`, `app` — each built from the sibling repository's own `Dockerfile` via a relative build context (`../rbrain-<context>`). The stack SHALL NOT duplicate or override sibling build logic beyond `build.context` (and build arguments the sibling's Dockerfile declares).

#### Scenario: Sibling Dockerfile is the build authority

- **WHEN** a sibling changes its runtime base image or build steps in its own `Dockerfile`
- **THEN** the next `docker compose build` SHALL pick the change up with no edit to `rbrain-deploy`

### Requirement: Complete internal environment wiring

The compose file SHALL set every environment variable each service requires, with service-to-service URLs addressing compose service names over the internal network (never `localhost`): gateway receives `JWT_SECRET`, `CORS_ALLOWED_ORIGINS` (defaulting to the app's browser-facing origin, `http://localhost:3000`, operator-overridable), plus `IDENTITY_URL`, `CORTEX_URL`, `LEXICON_URL`, `ORACLE_URL`, `FORGE_URL`, `CHRONICLE_URL`; identity receives `DATABASE_URL`, `JWT_SECRET`, `NATS_URL`; lexicon and oracle receive `DATABASE_URL`, `NATS_URL`; forge and chronicle receive `DATABASE_URL`; cortex receives `DATABASE_URL`, `NATS_URL`, `LEXICON_URL`, `ORACLE_URL`, `FORGE_URL`, and the `LLM_PROVIDER` configuration; app receives `GATEWAY_URL` (the in-network gateway base URL its BFF proxy calls, per ADR 0001) and `PUBLIC_GATEWAY_URL` (the browser-facing gateway URL, used only for the OAuth top-level navigation redirect). `JWT_SECRET` SHALL be the same value for identity and gateway, sourced from the operator environment.

#### Scenario: Identity and gateway share the signing secret

- **WHEN** a user registers through the stack and then calls a protected route with the returned JWT
- **THEN** the gateway SHALL verify the token successfully, proving both containers received the same `JWT_SECRET`

#### Scenario: No localhost across containers

- **WHEN** the compose file is inspected for `*_URL` and `NATS_URL` values
- **THEN** every cross-service value SHALL reference a compose service name; `localhost`/`127.0.0.1` SHALL appear only in host-facing examples, never in container-to-container wiring

#### Scenario: The browser origin is CORS-admitted

- **WHEN** the app served on its host port issues a cross-origin request to the gateway (e.g. `GET /articles` with `Origin: http://localhost:3000`)
- **THEN** the gateway SHALL answer with the matching `Access-Control-Allow-Origin` header, and preflights on the CORS-covered routes SHALL succeed

#### Scenario: The app proxies with in-network wiring

- **WHEN** a logged-in browser calls the app's `/api/decks`
- **THEN** the app server SHALL reach the gateway through `GATEWAY_URL` (compose service name), and no gateway URL SHALL be baked into the app's client bundle at build time

### Requirement: Secrets are referenced, never committed

The repository SHALL commit only a `.env.example` with placeholder values. Real secrets (`JWT_SECRET`, LLM provider keys, OAuth client secrets) SHALL be supplied via the operator's environment or a gitignored `.env`. No secret value SHALL appear in the compose file, the init scripts, or CI configuration.

#### Scenario: Repository is free of secret values

- **WHEN** the repository tree is scanned
- **THEN** only `.env.example` placeholder values SHALL be present, and `.env` SHALL be gitignored

### Requirement: Host port exposure follows the canonical map

The stack SHALL expose service HTTP ports on the host exactly per the canonical local-development port map in `service-topology` (lexicon `8080`, cortex `8081`, oracle `8082`, identity `8083`, chronicle `8084`, forge `8085`, gateway `8090`, app `3000`). Shared infrastructure SHALL use dedicated host ports outside the per-repo development ranges — PostgreSQL on `5440`, NATS on `4240` (monitoring `8240`) — so the platform stack can run alongside any per-repo development stack without collision.

#### Scenario: Recorded smoke recipes keep working

- **WHEN** an operator replays a smoke recipe that targets `http://localhost:8090` (gateway) and `http://localhost:3000` (app)
- **THEN** the requests SHALL reach the stack's containers without port remapping

#### Scenario: Stack coexists with a per-repo dev stack

- **WHEN** `rbrain-lexicon`'s development compose (Postgres on `5432`, NATS on `4222`) is already running and the platform stack starts
- **THEN** no host port conflict SHALL occur

### Requirement: Health-gated startup ordering

Every infrastructure container (PostgreSQL, NATS) SHALL declare a healthcheck, and every service container SHALL gate its start on the healthy state of the infrastructure it requires (`depends_on` with `condition: service_healthy`). Service containers whose image can execute an in-container probe (`cortex` on `python:*-slim`, `app` on `node:*-alpine`) SHALL declare a healthcheck probing `GET /health` (per `repository-conventions`). Service containers built on distroless images (the six Rust services) SHALL NOT be required to declare an in-container healthcheck — distroless ships no executable probe — and their health SHALL be asserted by a host-side `GET /health` sweep once the stack is up. The stack SHALL NOT rely on restart loops as the ordering mechanism.

#### Scenario: Service waits for its database

- **WHEN** the stack starts from cold
- **THEN** no persistent service SHALL attempt its boot-time migrations before the PostgreSQL container reports healthy

#### Scenario: Probe-capable images declare healthchecks

- **WHEN** the compose file is inspected
- **THEN** `cortex` and `app` SHALL declare a `GET /health` healthcheck, and PostgreSQL and NATS SHALL declare infrastructure healthchecks

#### Scenario: Distroless services are covered by the host-side sweep

- **WHEN** the stack is up and the operator runs the health sweep against the canonical host ports
- **THEN** every service — including the six distroless Rust services — SHALL answer `GET /health` with the canonical payload

### Requirement: Memory limits derive from the committed budgets

Every container in the stack SHALL declare a memory limit equal to its context's budget in `language-runtimes/memory-budgets.yaml` (services) or that file's `external:` block (infrastructure). Raising a limit SHALL happen only through an OpenSpec change amending `memory-budgets.yaml` first.

#### Scenario: Limits match the budgets file

- **WHEN** the compose file's memory limits are compared against `memory-budgets.yaml`
- **THEN** every container's limit SHALL equal its budgeted value, and the sum SHALL remain under the platform ceiling

### Requirement: Stack composition closure at v1

The v1 stack SHALL consist of exactly ten containers: `postgres`, `nats`, and the eight runtime services. Redis SHALL NOT be part of the v1 stack — no service consumes a cache yet; the first change introducing a Redis consumer SHALL amend this capability to add the container with its budgeted limit. Adding, removing, or replacing any container SHALL require a MODIFIED delta on this requirement.

#### Scenario: Composition is closed

- **WHEN** `docker compose config --services` is run
- **THEN** it SHALL list exactly `postgres`, `nats`, `gateway`, `identity`, `lexicon`, `oracle`, `forge`, `chronicle`, `cortex`, `app`

