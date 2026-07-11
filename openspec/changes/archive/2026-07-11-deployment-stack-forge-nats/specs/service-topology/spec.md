## MODIFIED Requirements

### Requirement: Canonical local-development port map

The platform SHALL maintain a single canonical map of the host ports each context uses in **local development**, where all contexts run on one machine and the production `PORT`-defaults-to-`8080` rule (see `repository-conventions` → "Port binding honors a PORT environment variable") would otherwise collide. This map is a local collision-avoidance convention and SHALL NOT change the production bind default.

The canonical map is:

| context | HTTP | NATS | Postgres |
|---|---|---|---|
| lexicon | 8080 | 4222 | 5432 |
| cortex | 8081 | — (uses identity's NATS, 4224) | 5433 |
| oracle | 8082 | 4223 | 5434 |
| identity | 8083 | 4224 | 5435 |
| chronicle | 8084 | — (reserved) | 5436 |
| forge | 8085 | — (uses lexicon's NATS, 4222) | 5437 |
| gateway | 8090 | — | — |
| app (frontend) | 3000 | — | — |

Rules:

- Each context's `.env.example` SHALL reflect these ports: its own HTTP port (via `PORT` or the equivalent runtime flag) and the host ports of every service and datastore it connects to.
- The gateway SHALL bind `8090` and SHALL address downstream services at their HTTP ports above (`identity:8083`, `cortex:8081`, `lexicon:8080`, `oracle:8082`).
- cortex SHALL connect to NATS at `4224` (identity's instance, where the `IDENTITY_EVENTS` stream lives); it does not run its own NATS.
- forge SHALL connect to NATS at `4222` (lexicon's instance, where the `LEXICON_CARDS` stream lives); it does not run its own NATS and SHALL NOT create or mutate `LEXICON_CARDS`.
- chronicle (`8084`) port is reserved for when that service comes online.
- New contexts SHALL claim the next free HTTP port in the `808x` block (and Postgres in the `543x` block, NATS in the `422x` block if they publish events) via an OpenSpec change updating this table.

#### Scenario: Gateway example points at real downstream ports

- **WHEN** a developer copies `rbrain-gateway/.env.example` to `.env` and starts the stack per the recipes
- **THEN** `IDENTITY_URL`, `CORTEX_URL`, `LEXICON_URL`, and `ORACLE_URL` SHALL resolve to `8083`, `8081`, `8080`, and `8082` respectively, and the gateway SHALL bind `8090`; every downstream call SHALL reach a running service

#### Scenario: A service example lists every port it needs

- **WHEN** a context's `.env.example` is reviewed
- **THEN** it SHALL state the context's own HTTP port and the host ports of each datastore and service it depends on, all matching this table (e.g. cortex lists its `NATS_URL` at `4224`, its `DATABASE_URL` at `5433`, and `LEXICON_URL`/`ORACLE_URL` at `8080`/`8082`)

#### Scenario: A new context claims a port via the table

- **WHEN** a new `rbrain-*` context is introduced that binds an HTTP port
- **THEN** the change introducing it SHALL add a row to this table claiming the next free `808x` HTTP port (and `543x`/`422x` ports as needed), rather than picking an undocumented number

#### Scenario: Forge connects to lexicon's NATS, not its own

- **WHEN** `rbrain-forge/.env.example` is reviewed
- **THEN** it SHALL list `NATS_URL` at `4222` (lexicon's instance), matching this table; forge SHALL NOT reserve or bind its own NATS port for this purpose
