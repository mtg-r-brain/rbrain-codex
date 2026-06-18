# service-topology Specification

## Purpose
TBD - created by archiving change platform-architecture. Update Purpose after archive.
## Requirements
### Requirement: Gateway is the sole public ingress

`rbrain-gateway` SHALL be the only context exposing an HTTP interface reachable from outside the cluster. No other backend context SHALL bind a port to a public network interface. The frontend `rbrain-app` SHALL direct all backend traffic to the gateway and SHALL NOT call any other backend context directly.

#### Scenario: Frontend backend traffic

- **WHEN** `rbrain-app` issues a request to any backend capability (authentication, chat, blog, card search)
- **THEN** the request SHALL be addressed to the gateway's public hostname and SHALL NOT bypass it

#### Scenario: Backend exposure check

- **WHEN** deployment manifests are validated for production
- **THEN** only the gateway SHALL declare a public ingress; any other context declaring one SHALL cause the deployment to fail

### Requirement: Authoritative synchronous call graph

The platform SHALL maintain an authoritative synchronous call graph at `openspec/specs/service-topology/sync-graph.yaml` listing every allowed HTTP edge between contexts as `(caller, callee, purpose)`. The graph SHALL contain exactly the following edges and no others:

- `app → gateway` — all frontend traffic
- `gateway → identity` — authentication and account operations
- `gateway → cortex` — chat and agent invocations
- `gateway → chronicle` — public blog content reads only; editorial authoring is operator-internal under chronicle's `/admin/*` prefix and is NOT gateway-proxied
- `gateway → forge` — user-scoped deck CRUD (deck storage and retrieval)
- `cortex → lexicon` — card lookups used as agent tools
- `cortex → oracle` — rules queries used as agent tools
- `cortex → forge` — deck operations used as agent tools

`forge` is intentionally **dual-role**: it is both a cortex agent-tool backend (parse/analyze) and a gateway-fronted CRUD backend (it owns user decks). This is the one backend the gateway calls directly that is also a cortex tool; it is permitted because forge owns user data (decks), not merely derived tool answers.

The `gateway → chronicle` edge is **read-only** at the public boundary: chronicle's editorial authoring lives under its reserved `/admin/*` prefix (per `lexicon-api-admin-carveout`), which the gateway rejects for external traffic. The edge remains in the graph because the gateway proxies chronicle's public blog reads.

Any new synchronous call between contexts SHALL be added to this graph via an OpenSpec change before implementation.

#### Scenario: Unlisted edge is forbidden

- **WHEN** a developer attempts to add an HTTP call from `chronicle` to `lexicon`
- **THEN** the call SHALL be rejected by code review or CI policy because the edge `chronicle → lexicon` is not in `sync-graph.yaml`

#### Scenario: Pure tool service is not directly callable from gateway

- **WHEN** the gateway receives a request that would require card data
- **THEN** the gateway SHALL route the request to `cortex`, and `cortex` SHALL call `lexicon`; the gateway SHALL NOT call `lexicon` directly (lexicon and oracle remain cortex-only tool backends)

#### Scenario: Gateway may call forge for deck CRUD

- **WHEN** an authenticated user saves or reads a deck
- **THEN** the gateway MAY proxy the request directly to `forge` (the `gateway → forge` edge), because deck storage is user data forge owns, distinct from forge's cortex-tool role

#### Scenario: Chronicle authoring is not a gateway edge

- **WHEN** a contributor proposes routing editorial authoring (`POST /admin/articles`) through the gateway
- **THEN** the proposal SHALL be rejected: the `gateway → chronicle` edge is read-only; authoring is operator-internal under `/admin/*` and not gateway-proxied

### Requirement: Asynchronous events use NATS JetStream

Cross-context notifications that are not part of a request-response path SHALL be delivered over NATS JetStream. Producers SHALL NOT depend on the availability of consumers. Each event SHALL be published on a subject that follows the naming convention `rbrain.<producer-context>.<event-name>`, where `<event-name>` is lowercase kebab-case describing the fact (e.g., `rbrain.lexicon.card-released`, `rbrain.forge.deck-saved`).

#### Scenario: Producer is decoupled from consumer

- **WHEN** `lexicon` publishes a `card-released` event
- **THEN** the publish SHALL succeed regardless of whether any consumer is currently running, and the message SHALL be retained for replay according to the stream's retention policy

#### Scenario: Subject naming convention

- **WHEN** a new event is introduced
- **THEN** its subject SHALL match the pattern `rbrain.<producer-context>.<event-name>` and SHALL be documented in the producer context's AGENTS.md

#### Scenario: Synchronous request is not encoded as an event

- **WHEN** a context needs an immediate answer (e.g., the result of a card lookup)
- **THEN** it SHALL use the synchronous call graph and SHALL NOT simulate a request-response pattern over NATS

### Requirement: No circular synchronous dependencies

The synchronous call graph defined in `sync-graph.yaml` SHALL be a directed acyclic graph (DAG). A change introducing a cycle SHALL be rejected.

#### Scenario: Cycle detection on graph change

- **WHEN** an OpenSpec change proposes adding an edge that would create a cycle (e.g., `lexicon → cortex`, given the existing `cortex → lexicon`)
- **THEN** validation tooling SHALL detect the cycle and reject the change

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
| forge | 8085 | 4225 | 5437 |
| gateway | 8090 | — | — |
| app (frontend) | 3000 | — | — |

Rules:

- Each context's `.env.example` SHALL reflect these ports: its own HTTP port (via `PORT` or the equivalent runtime flag) and the host ports of every service and datastore it connects to.
- The gateway SHALL bind `8090` and SHALL address downstream services at their HTTP ports above (`identity:8083`, `cortex:8081`, `lexicon:8080`, `oracle:8082`).
- cortex SHALL connect to NATS at `4224` (identity's instance, where the `IDENTITY_EVENTS` stream lives); it does not run its own NATS.
- chronicle (`8084`) and forge (`8085`) ports are reserved for when those services come online; forge's NATS port (`4225`) is reserved for its `rbrain.forge.*` producer role.
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

