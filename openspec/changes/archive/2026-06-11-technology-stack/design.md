## Context

`platform-architecture` locked the topology and conventions but stopped short of the stack. `ideas/03-stack.md` proposed a polyglot mix (Rust for data/infra services, Python for LLM orchestration, TypeScript for the frontend) under a hard frugality constraint (~786 MB total RAM target on commodity infrastructure). This design crystallizes those proposals into a versioned, per-context contract that the upcoming `scaffold-sibling-repos` change can mechanically apply.

The constraint that drives almost every decision below is **frugality**: the platform must run on a single VPS or a homelab without dedicated tuning. That excludes JVM services, heavyweight buses, and self-hosted vector databases at this stage.

## Goals / Non-Goals

**Goals:**

- Provide a single, unambiguous source of truth for the runtime, datastore, messaging, and LLM-abstraction choices.
- Make the frugality constraint enforceable: every BC declares a memory ceiling, the platform-wide sum is verifiable.
- Lock minimum versions precisely enough that CI can fail on a stale toolchain.
- Stay revisable: the goal is not to lock the stack forever; it is to lock it long enough that the first vertical features ship without re-litigation.

**Non-Goals:**

- Justifying the choice of MTG itself or the product scope — those are settled in `ideas/01-project-vision.md`.
- Detailing observability, secret management, container runtime, CI provider — `deployment-topology` owns those.
- Locking the LLM provider — the proposal explicitly states there is no default; every deployment chooses.
- Migration planning to alternative datastores or messaging — non-goals listed in the proposal (pgvector → Qdrant, LangGraph → pydantic-ai). They will get their own ADRs when triggered.
- Per-context internal architecture (crates, modules, folder layout).

## Decisions

### D1. Per-context runtime allocation is frozen

| Context | Runtime | Framework / Stack |
|---|---|---|
| `gateway` | Rust | Axum + Tokio + Tower middleware |
| `identity` | Rust | Axum + Tokio + SQLx |
| `lexicon` | Rust | Axum + Tokio + SQLx + reqwest (Scryfall sync) |
| `oracle` | Rust | Axum + Tokio + SQLx + pgvector queries |
| `forge` | Rust | Axum + Tokio + SQLx |
| `chronicle` | Rust | Axum + Tokio + SQLx |
| `cortex` | Python 3.12 | FastAPI + LangGraph + instructor + anthropic SDK |
| `app` | TypeScript | Next.js 15 (App Router, RSC, streaming) |
| `deploy` | none | docker-compose + Helm chart (no runtime) |
| `codex` | none | OpenSpec workflow + ADRs (no runtime) |

**Rationale:** Rust dominates the data and infra plane because the frugality constraint forbids JVM and tolerates only thin runtimes; Axum + Tokio gives the same ergonomics across the seven Rust services. Python is the only viable choice for `cortex` because the LLM ecosystem (LangGraph, instructor, official Anthropic SDK, structured output libraries) is Python-native and the cost of replicating it in Rust is disproportionate. Next.js for `app` because the frontend needs SSR + WebSocket streaming for chat, and the ecosystem is uncontested at this scale.

**Alternatives considered:**

- **All-Rust including cortex** (use `async-openai`, hand-rolled tool-calling loop) — rejected: drops months on rebuilding LangGraph equivalents and loses access to the `instructor` library for structured output. The frugality gain (~120 MB) does not justify the velocity loss.
- **Go instead of Rust** — rejected: Rust's memory ceiling is ~30% lower than Go's for the same workload, and the team's stated trajectory favors Rust expertise.
- **Python everywhere** — rejected: a Python `gateway` and `lexicon` would blow the RAM budget (~150 MB each vs. ~30 MB for Rust).

### D2. Minimum versions are precise and enforced in CI

| Component | Minimum | Hard floor reason |
|---|---|---|
| Rust | 1.83 (stable, 2024-11) | Async traits in stable, `let chains` in match guards |
| Python | 3.12 | PEP 695 type aliases, faster startup, `tomllib` |
| Node.js | 22 LTS | Native WebSocket, V8 12.x improvements for Next.js 15 |
| Next.js | 15 | App Router stable, Partial Prerendering, Turbopack dev |
| Axum | 0.7 | Tower 0.5 alignment, `IntoResponse` ergonomics |
| Tokio | 1.40 | Stable `tokio::task::Builder` and runtime metrics |
| SQLx | 0.8 | Stable migration story, query!() macros |
| PostgreSQL | 16 | Logical replication improvements, `pg_stat_io`, JSON merge |
| pgvector | 0.7 | HNSW index improvements, half-precision vectors |
| Redis | 7.4 | Functions, ACLs, lower memory overhead on hashes |
| NATS server | 2.10 | JetStream Consumer pull-based subscription stable |

CI in `rbrain-codex` validates the floors via `scripts/validate-stack.sh`. Each sibling repo's CI imports the same script (or replicates the assertions) to guarantee toolchain conformance per-repo.

**Alternatives considered:**

- **No version floor, "stable recent" wording** — rejected: not testable; rust-toolchain pinning drifts across repos. Bumping is cheap via an OpenSpec change.
- **MSRV one minor behind** — rejected for this project's scale: the maintainer is solo at this stage and bleeding-edge Rust gives meaningful ergonomics gains.

### D3. PostgreSQL + pgvector is the single relational + vector store

One PostgreSQL 16 instance with the `pgvector` extension serves every BC that needs persistence. Each BC owns its own schema (`identity.*`, `lexicon.*`, `oracle.*`, `forge.*`, `chronicle.*`); cross-schema reads are forbidden and enforced by per-BC role grants.

**Rationale:** Splitting into multiple Postgres instances would double the memory cost (~256 MB each) without isolation gains at this scale. Splitting into a separate vector database (Qdrant, Weaviate, Milvus) was tempting for `oracle` but loses the ability to JOIN embeddings with relational metadata in a single query — and adds another ~512 MB service. pgvector at 0.7 is fast enough for ≤ 10M embeddings, which the comprehensive rules corpus does not approach.

**Alternatives considered:**

- **Elasticsearch for full-text** — rejected on memory (~1 GB JVM) and operational complexity. PostgreSQL's GIN + tsvector is sufficient for card-text search at this scale.
- **Qdrant for vector** — rejected at v1 but kept as an upgrade path (proposal non-goal); pgvector + HNSW handles current scale.

### D4. NATS JetStream is the sole async bus

One NATS server with JetStream enabled handles all asynchronous notifications. Subject naming follows the `rbrain.<ctx>.<event>` convention from `service-topology`. Default stream retention is 7 days; consumers are pull-based per the official guidance.

**Rationale:** Memory footprint (~40 MB) is an order of magnitude below Kafka or RabbitMQ. JetStream provides at-least-once delivery with replay, which covers every integration pattern listed so far. Kafka's ordering guarantees are not needed at this scale.

**Alternatives considered:**

- **Kafka (KRaft mode)** — rejected on memory (~512 MB).
- **Redis Streams** — rejected: re-uses the cache layer for a fundamentally different concern, couples lifecycles, and lacks JetStream's stream-replay tooling.
- **PostgreSQL LISTEN/NOTIFY** — rejected: no persistence, no replay, no consumer groups.

### D5. LlmPort abstracts three reference providers; no default

`rbrain-cortex` exposes an abstract `LlmPort` with the methods `generate(prompt) -> response`, `tool_call(prompt, tools) -> tool_invocations`, and `embeddings(texts) -> vectors`. Three implementations ship in v1: `ClaudeProvider` (anthropic SDK), `OllamaProvider` (HTTP to a local Ollama instance), `OpenAiProvider` (openai SDK).

No default provider is set at the spec or code level. Each deployment SHALL set `LLM_PROVIDER` (one of `claude | ollama | openai`) and its provider-specific credentials. Starting `cortex` without an explicit provider SHALL fail at boot with a clear error.

**Rationale:** Hard-coding a default would either bind every deployment to the Anthropic API (cost), to local Ollama (quality), or to OpenAI (vendor preference). All three are wrong for some deployments. Explicit configuration moves the choice to the right layer.

**Alternatives considered:**

- **Default = Claude** — rejected: deployments without an Anthropic key would fail late, not at boot, leading to confusing first-run errors.
- **Default = Ollama** — rejected: requires a local model server; not viable for cloud-first deployments.
- **Single provider in v1, abstraction later** — rejected: porting from a concrete provider to a port is high-friction once consumers depend on its types. Pay the abstraction cost upfront.

### D6. Per-context memory budget enforces frugality

Each `OWNERSHIP.yaml` SHALL declare a `max_rss_mb` integer. The catalog of budgets, derived from `ideas/03-stack.md` and adjusted for headroom, is:

| Context | `max_rss_mb` | Source |
|---|---|---|
| `gateway` | 35 | Rust + Tower middleware |
| `identity` | 25 | thin Rust + SQLx pool |
| `lexicon` | 30 | Rust + Scryfall sync buffers |
| `oracle` | 40 | Rust + pgvector query workspace |
| `forge` | 30 | Rust + deck parsers |
| `chronicle` | 25 | Rust + content cache |
| `cortex` | 200 | Python 3.12 + LangGraph + provider SDKs |
| `app` | 100 | Next.js 15 SSR runtime |
| `deploy` | 0 | no runtime |
| `codex` | 0 | no runtime |
| **services total** | **485** | |
| PostgreSQL + pgvector | 256 | external dependency |
| Redis | 50 | external dependency |
| NATS JetStream | 40 | external dependency |
| **grand total** | **831** | |

The grand total is the platform-wide ceiling for any single-node deployment. Sibling repos' CI may run a heap snapshot under load and assert their RSS stays under the declared `max_rss_mb`.

**Alternatives considered:**

- **Global ceiling only, no per-BC budget** — rejected: a single offender (e.g. `cortex` ballooning to 600 MB) would silently swallow the whole budget. Per-BC ceilings localize the failure.
- **CPU and disk budgets too** — rejected as scope creep; RAM is the binding constraint at this scale. Add CPU budgets later if a deployment proves IO-bound.

## Risks / Trade-offs

- **Rust monoculture for the data plane raises bus-factor risk.** → Mitigation: the seven Rust services share the same Axum + Tokio + SQLx baseline; a contributor familiar with one is productive on the others. Documentation in each repo's AGENTS.md mirrors the same layout.
- **Polyglot stack (Rust + Python + TS) raises onboarding cost.** → Mitigation: language is BC-scoped; a contributor working only on `app` never touches Rust. The frontier between languages is HTTP, which normalizes everything.
- **`cortex` is the largest single budget consumer (~200 MB) and the most likely to drift.** → Mitigation: CI-side memory check on `cortex` is mandatory; bumping the budget requires an OpenSpec change documenting why.
- **No default LLM provider means deployments fail at boot if misconfigured.** → Mitigation: that's the intended behavior; boot-time failure is preferable to runtime surprise. Documentation in `rbrain-cortex/AGENTS.md` will list the three providers and the required env vars.
- **Version floors will drift.** → Mitigation: a quarterly review is implicit; bumps go through an OpenSpec change that updates the table in this design.
- **Single PostgreSQL instance is a single point of failure.** → Mitigation: standard PostgreSQL HA tooling (streaming replication, pgbouncer) is available when needed; v1 ships single-node intentionally for frugality.

## Migration Plan

No migration — nothing currently runs. The execution path is:

1. Land this change (proposal + design + 4 specs + tasks) in `rbrain-codex`.
2. Follow-up: amend `repository-conventions` to add `max_rss_mb` as a mandatory `OWNERSHIP.yaml` field. Tracked as a hand-off task.
3. `scaffold-sibling-repos` (future change) creates the 9 sibling repos against this stack.

Rollback is the standard OpenSpec mechanism: a new change amending this one.

## Open Questions

- **CI memory-check tooling**: `valgrind --tool=massif`? `bytehound`? `psutil` script? Defer to the tasks step.
- **Ollama model recommendation**: should the spec name a baseline (e.g. `llama3.1:8b-instruct`) or stay model-agnostic? Defer to a future cortex-specific spec.
- **PostgreSQL connection pool sizing**: per-BC vs. shared `pgbouncer` upstream. Defer to `deployment-topology`.
- **Embeddings model**: `text-embedding-3-small` (OpenAI) vs. `voyage-3-lite` vs. an open model via Ollama? Defer to a future `oracle` spec.
