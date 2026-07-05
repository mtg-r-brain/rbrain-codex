## MODIFIED Requirements

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
