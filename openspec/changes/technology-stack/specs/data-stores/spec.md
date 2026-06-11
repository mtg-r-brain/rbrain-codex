## ADDED Requirements

### Requirement: PostgreSQL is the sole relational + vector store

Every `rbrain-*` service that requires persistent structured storage or vector similarity search SHALL use a single shared PostgreSQL 16 instance with the `pgvector` extension installed. Introducing any other relational database (MySQL, SQLite for production, etc.) or vector database (Qdrant, Weaviate, Milvus) SHALL require an OpenSpec change.

Minimum versions:

- PostgreSQL: `>= 16.0`
- pgvector: `>= 0.7.0`

#### Scenario: Foreign datastore is rejected

- **WHEN** a sibling repo declares a dependency on SQLite, MySQL, Qdrant, or any other database in its build manifest
- **THEN** CI SHALL fail with a message pointing at this requirement

#### Scenario: pgvector extension is available

- **WHEN** any service starts up and connects to the platform PostgreSQL instance
- **THEN** the connection SHALL succeed only if `CREATE EXTENSION IF NOT EXISTS vector` has been applied; deployment tooling SHALL ensure this

### Requirement: Schema ownership per bounded context

Each persistent bounded context (`identity`, `lexicon`, `oracle`, `forge`, `chronicle`) SHALL own exactly one PostgreSQL schema named identically to the context (`identity`, `lexicon`, `oracle`, `forge`, `chronicle`). A service SHALL access only its own schema; cross-schema reads or writes SHALL be forbidden and enforced via per-context PostgreSQL roles with explicit `USAGE` and `SELECT/INSERT/UPDATE/DELETE` grants restricted to the owning schema.

#### Scenario: Cross-schema read is blocked at the database layer

- **WHEN** a connection authenticated as the `oracle` role attempts to `SELECT FROM forge.deck`
- **THEN** PostgreSQL SHALL return a permission-denied error

#### Scenario: Service connects under its own role

- **WHEN** `rbrain-cortex` opens a database connection
- **THEN** the connection SHALL authenticate as the `cortex` role (or its read-only sub-role for tool calls) and SHALL NOT be granted superuser privileges

### Requirement: Migrations are owned per schema

Schema migrations SHALL be managed per bounded context using SQLx migrations (for Rust services) or Alembic (for `cortex`). The migrations of one context SHALL NOT touch another context's schema. Migrations SHALL be applied at service start (or via a dedicated migration container in production deployments).

#### Scenario: Migration scope violation

- **WHEN** a migration file under `rbrain-oracle/migrations/` issues a statement touching the `lexicon` schema
- **THEN** code review or a `scripts/validate-migrations.sh` check SHALL reject the migration

#### Scenario: Migration applies at boot

- **WHEN** an `rbrain-*` Rust service starts in any environment
- **THEN** it SHALL apply any pending SQLx migrations under its own `migrations/` folder before serving requests, or SHALL exit with a clear error if migrations fail

### Requirement: Redis is the sole cache layer

Every `rbrain-*` service that needs an ephemeral key-value cache (session storage, Scryfall response cache, rate-limit counters) SHALL use a single shared Redis instance. Redis SHALL NOT be used as a primary datastore or as an event bus.

Minimum versions:

- Redis: `>= 7.4`

#### Scenario: Redis is rejected as a persistent store

- **WHEN** a service uses Redis for data that must survive a cache flush or instance restart
- **THEN** the design SHALL be rejected; the data SHALL live in PostgreSQL instead

#### Scenario: Redis is rejected as an event bus

- **WHEN** a service uses Redis Streams or Pub/Sub for cross-context notifications
- **THEN** the design SHALL be rejected; cross-context async events SHALL use NATS JetStream per the `messaging-runtime` capability
