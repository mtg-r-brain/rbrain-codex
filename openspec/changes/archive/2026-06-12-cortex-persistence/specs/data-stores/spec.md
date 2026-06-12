## MODIFIED Requirements

### Requirement: Schema ownership per bounded context

Each persistent bounded context (`identity`, `lexicon`, `oracle`, `forge`, `chronicle`, `cortex`) SHALL own exactly one PostgreSQL schema named identically to the context (`identity`, `lexicon`, `oracle`, `forge`, `chronicle`, `cortex`). A service SHALL access only its own schema; cross-schema reads or writes SHALL be forbidden and enforced via per-context PostgreSQL roles with explicit `USAGE` and `SELECT/INSERT/UPDATE/DELETE` grants restricted to the owning schema.

The authoritative list of persistent BCs lives both in this requirement and in the companion configuration files `openspec/specs/data-stores/postgres-roles.yaml` (per-role privileges) and `openspec/specs/data-stores/postgres-baseline.md` (schema bootstrap policy). The three sources SHALL stay in sync; modifying any one requires an OpenSpec change that updates the others atomically.

#### Scenario: Cross-schema read is blocked at the database layer

- **WHEN** a connection authenticated as the `oracle` role attempts to `SELECT FROM forge.deck`
- **THEN** PostgreSQL SHALL return a permission-denied error

#### Scenario: Service connects under its own role

- **WHEN** `rbrain-cortex` opens a database connection
- **THEN** the connection SHALL authenticate as the `cortex` role (or its read-only sub-role for tool calls) and SHALL NOT be granted superuser privileges

#### Scenario: cortex owns its conversation state

- **WHEN** `rbrain-cortex` persists or fetches a conversation
- **THEN** the operation SHALL target the `cortex` schema; `rbrain-cortex` SHALL NOT read or write rows in `lexicon`, `oracle`, `forge`, `chronicle`, or `identity` schemas — agent-tool calls to those contexts go through HTTP (per the `service-topology` sync graph), not direct SQL

#### Scenario: cortex appears in the postgres-roles registry

- **WHEN** the codex `validate-data-stores` script iterates `postgres-roles.yaml`
- **THEN** the script SHALL find a `cortex` entry with `schema: cortex`, `privileges: [USAGE, SELECT, INSERT, UPDATE, DELETE]`, `superuser: false`, and `cross_schema: []`; absence of that entry SHALL fail validation
