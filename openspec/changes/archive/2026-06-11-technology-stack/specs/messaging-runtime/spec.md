## ADDED Requirements

### Requirement: NATS JetStream is the sole async messaging runtime

Every cross-context asynchronous notification SHALL be delivered via NATS with JetStream enabled. Introducing any other asynchronous bus (Kafka, RabbitMQ, AWS SQS, Google Pub/Sub, Redis Streams, PostgreSQL LISTEN/NOTIFY) SHALL require an OpenSpec change amending this requirement.

Minimum versions:

- NATS server: `>= 2.10`
- JetStream: enabled

#### Scenario: Kafka dependency is rejected

- **WHEN** a sibling repo's manifest declares a Kafka client (`rdkafka`, `confluent-kafka-python`, etc.)
- **THEN** CI SHALL fail with a message pointing at this requirement

#### Scenario: JetStream is required, not optional

- **WHEN** the NATS server is started without `-js` or with JetStream disabled in its configuration
- **THEN** deployment tooling SHALL detect the missing JetStream support and SHALL refuse to mark the deployment ready

### Requirement: At-least-once delivery with replay

JetStream streams that back cross-context events SHALL be configured for at-least-once delivery with a minimum retention of 7 days. Consumers SHALL be pull-based (per the official NATS guidance for durable workloads).

#### Scenario: Consumer survives a downtime window

- **WHEN** an `oracle` consumer is offline for 4 days while `lexicon` publishes `card-released` events
- **THEN** when the consumer resumes, it SHALL receive the events that occurred during the downtime, in order per subject

#### Scenario: Push-based consumer for cross-context durable work is rejected

- **WHEN** a sibling repo declares a push-based JetStream consumer for a durable workload
- **THEN** code review SHALL require switching to a pull-based consumer or filing an OpenSpec change

### Requirement: Subject naming follows the platform convention

All JetStream subjects used for cross-context events SHALL match the pattern defined in the `service-topology` capability: `rbrain.<producer-context>.<event-name>`. Subjects outside this pattern SHALL NOT be permitted, except for an explicitly reserved control plane prefix `rbrain.system.*` used by `deploy` for platform-level signals.

#### Scenario: Non-conformant subject is rejected

- **WHEN** a service attempts to publish on the subject `forge.deck.saved` (missing `rbrain.` prefix)
- **THEN** a publish-side wrapper or middleware SHALL reject the call; CI SHALL detect such subjects via grep over the codebase and fail the build

#### Scenario: Control-plane prefix is reserved

- **WHEN** any service other than `deploy` publishes on `rbrain.system.*`
- **THEN** validation tooling SHALL flag the violation

### Requirement: No synchronous RPC over NATS

NATS SHALL NOT be used to simulate synchronous request-response patterns between contexts (no NATS request-reply for cross-context calls). Synchronous calls SHALL go through HTTP per the `service-topology` capability.

#### Scenario: Cross-context request-reply is rejected

- **WHEN** a service uses `nats.request(subject, payload)` to call another context and await a reply on the same connection
- **THEN** code review SHALL reject the design; the call SHALL be migrated to HTTP via the synchronous call graph
