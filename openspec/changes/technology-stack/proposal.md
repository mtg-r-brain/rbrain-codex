## Why

The `platform-architecture` change locked the bounded contexts, topology, and repository conventions, but said nothing about which runtime each context uses, which datastore backs them, how async events flow, or how the LLM is abstracted. Without this contract, the upcoming `scaffold-sibling-repos` change has no basis to decide whether `rbrain-lexicon` is a Rust binary or a Python service, and no basis to enforce the frugality constraint (~786 MB target) declared in `ideas/03-stack.md`. Locking the stack now turns "frugality" from a slogan into a testable contract.

## What Changes

- Freeze the per-context runtime allocation: `gateway`, `identity`, `lexicon`, `oracle`, `forge`, and `chronicle` are Rust services (Axum + Tokio + SQLx); `cortex` is a Python 3.12 service (FastAPI + LangGraph); `app` is a Next.js 15 / TypeScript application. Any future migration of a context to a different runtime requires an OpenSpec change amending this allocation.
- Declare PostgreSQL 16 with the `pgvector` extension as the single relational + vector datastore, and Redis as the cache layer (sessions, Scryfall lookup cache).
- Declare NATS JetStream as the sole asynchronous messaging runtime; explicitly forbid alternative buses (Kafka, RabbitMQ) without an OpenSpec change.
- Define a stable `LlmPort` abstraction in `rbrain-cortex` with three first-class providers (`ClaudeProvider`, `OllamaProvider`, `OpenAiProvider`). No default provider is set at the spec level — every deployment SHALL declare its provider explicitly via configuration.
- Introduce a per-context memory budget (`max_rss_mb`) declared in each repo's `OWNERSHIP.yaml`, with values derived from `ideas/03-stack.md`'s footprint table. The sum across all contexts SHALL stay under a global RAM target.

## Capabilities

### New Capabilities

- `language-runtimes`: Per-bounded-context runtime assignment (Rust / Python / TypeScript), version floors, and per-context memory budgets enforcing the platform frugality constraint.
- `data-stores`: PostgreSQL + pgvector as the single relational + vector store, Redis as the cache; schema migration ownership and connection pooling expectations.
- `messaging-runtime`: NATS JetStream as the sole async bus, stream retention defaults, subject pattern enforcement (delegated to `service-topology`'s naming convention).
- `llm-abstraction`: The `LlmPort` interface contract, the three reference providers, configuration surface, and the no-default-provider rule.

### Modified Capabilities

None — this change adds new specs and does not amend existing ones.

## Impact

- **`platform-architecture` specs**: `repository-conventions` will need to know about `max_rss_mb` as a new mandatory field in `OWNERSHIP.yaml`. This will be amended in a follow-up delta on `repository-conventions` (out of scope for this change; flagged as a follow-up).
- **`scaffold-sibling-repos` (future change)**: unblocked. Each sibling repo's scaffolding can now pick the right runtime, declare `OWNERSHIP.runtime` correctly, and start from a runtime-appropriate template.
- **Out of scope (non-goals)**:
  - Upgrade paths discussed in `ideas/03-stack.md` (pgvector → Qdrant beyond ~10M embeddings; LangGraph → pydantic-ai if graph complexity stays low). These will be handled via dedicated ADRs and OpenSpec changes only if and when the triggers materialize.
  - Observability stack, secret management, container runtime, and CI provider — those belong to a future `deployment-topology` change.
  - Per-context internal architecture (which crates, which Python modules) — `repository-conventions` leaves internal layout to each owner.
