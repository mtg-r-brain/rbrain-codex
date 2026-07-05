## Why

`deploy` is the only bounded context that has never been materialized. Yet three live specs already assign it concrete responsibilities that nothing fulfills today:

- `data-stores/postgres-baseline.md`: schemas, roles, grants, and the `vector` extension "are created by `rbrain-deploy` at first deployment" — from `postgres-roles.yaml` as the contract, SQL as the derived artefact.
- `messaging-runtime/jetstream-policy.yaml`: "how `rbrain-deploy` configures every stream and consumer".
- `bounded-contexts/catalog.yaml`: deploy "builds and operates the platform's local and production deployment artifacts (docker-compose, Helm chart)".

The operational consequence is concrete: bringing the platform up by hand takes ~15 containers/processes across seven repos (per-repo Postgres + NATS instances, six `*_URL` variables, a shared `JWT_SECRET`), which is why every live end-to-end smoke since 2026-06-13 has been deferred. Roughly thirty archived changes have never run together. The absence of a deployment stack is the root cause of the platform's verification debt.

This change defines `deployment-stack` v1: a single `docker compose` stack, owned by `rbrain-deploy`, that brings up the entire platform — shared infrastructure per the committed specs (one PostgreSQL, one NATS) plus the eight runtime services built from sibling checkouts. Helm (production) is explicitly out of scope for v1.

## What Changes

- ADD a `deployment-stack` capability with:
  - "Single shared PostgreSQL instance" — one PostgreSQL 16 + pgvector container; schemas/roles/grants derived from `postgres-roles.yaml`; `CREATE EXTENSION vector` at bootstrap (per `data-stores`).
  - "Single shared NATS JetStream broker" — one NATS ≥ 2.10 with JetStream enabled, replacing the per-repo dev brokers inside the stack (per `messaging-runtime`).
  - "Services build from sibling checkouts" — one container per runtime context (`gateway`, `identity`, `lexicon`, `oracle`, `forge`, `chronicle`, `cortex`, `app`), built from each sibling's own `Dockerfile`.
  - "Complete internal environment wiring" — every required env var set service-to-service over the compose network; `JWT_SECRET` shared between identity and gateway; LLM credentials passed through from the operator environment, never committed.
  - "Host port exposure" — HTTP ports follow the canonical local-dev port map (`service-topology`); stack infrastructure uses dedicated host ports so the stack coexists with per-repo dev stacks.
  - "Health-gated startup ordering" — infra healthchecks gate service start; service healthchecks probe `GET /health` (per `repository-conventions`).
  - "Memory limits from the committed budgets" — per-container limits derived from `memory-budgets.yaml`.
  - "Stack composition closure" — exactly ten containers at v1; Redis joins only when a first consumer exists.

## Capabilities

### New Capabilities

- `deployment-stack`: the contract for the platform's local deployment stack — composition, provisioning duties, wiring, ports, ordering, and limits.

### Modified Capabilities

None. `data-stores`, `messaging-runtime`, and `service-topology` already carry the requirements this capability implements; they are referenced, not amended.

## Impact

- **Contract here; implementation in `rbrain-deploy`** — a hand-scaffolded sibling (the scaffold script rejects `runtime: none` by spec), carrying `OWNERSHIP.yaml`, `AGENTS.md`, its own `openspec/`, the compose file, the Postgres init generator, and CI.
- **No new sync edge, no new schema, no new NATS subject.** deploy publishes nothing at v1 (`rbrain.system.*` remains reserved for it, unused).
- **Sibling repos untouched by this change.** Known Dockerfile drift (Rust base image vs. 1.88 toolchain floor; `app` build-time `NEXT_PUBLIC_GATEWAY_URL`) is expected to surface at first `docker compose build` and lands as small sibling chores then.
- **Specs touched**: codex `deployment-stack` (new).
