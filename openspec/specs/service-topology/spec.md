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

The platform SHALL maintain an authoritative synchronous call graph at `openspec/specs/service-topology/sync-graph.yaml` listing every allowed HTTP edge between contexts as `(caller, callee, purpose)`. The initial graph SHALL contain exactly the following edges and no others:

- `app → gateway` — all frontend traffic
- `gateway → identity` — authentication and account operations
- `gateway → cortex` — chat and agent invocations
- `gateway → chronicle` — blog content reads and edits
- `cortex → lexicon` — card lookups used as agent tools
- `cortex → oracle` — rules queries used as agent tools
- `cortex → forge` — deck operations used as agent tools

Any new synchronous call between contexts SHALL be added to this graph via an OpenSpec change before implementation.

#### Scenario: Unlisted edge is forbidden

- **WHEN** a developer attempts to add an HTTP call from `chronicle` to `lexicon`
- **THEN** the call SHALL be rejected by code review or CI policy because the edge `chronicle → lexicon` is not in `sync-graph.yaml`

#### Scenario: Tool service is not directly callable from gateway

- **WHEN** the gateway receives a request that would require card data
- **THEN** the gateway SHALL route the request to `cortex`, and `cortex` SHALL call `lexicon`; the gateway SHALL NOT call `lexicon` directly

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

