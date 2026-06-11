## 1. language-runtimes capability

- [x] 1.1 Create `openspec/specs/language-runtimes/runtime-allocation.yaml` mirroring the table from the spec: a flat mapping from context name to runtime (`rust`, `python`, `typescript`, `none`).
- [x] 1.2 Create `openspec/specs/language-runtimes/version-floors.yaml` listing every component with its `>=` floor (Rust, Python, Node.js, Next.js, Axum, Tokio, SQLx, FastAPI, LangGraph).
- [x] 1.3 Create `openspec/specs/language-runtimes/memory-budgets.yaml` listing per-context `max_rss_mb`, plus the external dependency budgets (postgres: 256, redis: 50, nats: 40) and the platform ceiling (1024).
- [x] 1.4 Write `scripts/validate-runtimes.sh` that asserts: (a) every context in `bounded-contexts/catalog.yaml` is present in `runtime-allocation.yaml`, (b) every runtime in the allocation is one of the four allowed values, (c) the sum of `max_rss_mb` plus external budgets does not exceed the ceiling.
- [x] 1.5 Extend `scripts/validate-repo.sh` (from `platform-architecture` tasks) to additionally assert `OWNERSHIP.runtime` matches `runtime-allocation.yaml` and `OWNERSHIP.max_rss_mb` matches `memory-budgets.yaml`.
- [x] 1.6 Wire all new validators into `rbrain-codex` CI.

## 2. data-stores capability

- [x] 2.1 Create `openspec/specs/data-stores/postgres-roles.yaml` listing the per-context PostgreSQL roles (`identity`, `lexicon`, `oracle`, `forge`, `chronicle`), each with its owned schema and the grant set (`USAGE` on schema, full DML on schema's relations, no superuser, no cross-schema grant).
- [x] 2.2 Document the `pgvector` and `tsvector` baseline usage policy in `openspec/specs/data-stores/postgres-baseline.md` (one paragraph each on extension activation, schema bootstrap, role provisioning).
- [x] 2.3 Document the Redis usage policy in `openspec/specs/data-stores/redis-baseline.md` (cache only; key naming `<ctx>:<purpose>:<id>`; TTLs mandatory; no persistence guarantees).
- [x] 2.4 Write `scripts/validate-data-stores.sh` that asserts each persistent context (`identity`, `lexicon`, `oracle`, `forge`, `chronicle`) is listed in `postgres-roles.yaml` and that every role's grants match the no-cross-schema rule.

## 3. messaging-runtime capability

- [x] 3.1 Create `openspec/specs/messaging-runtime/jetstream-policy.yaml` declaring the default stream configuration (`retention: limits`, `max_age: 7 days`, `storage: file`, `discard: old`) and the default consumer configuration (`type: pull`, `ack_policy: explicit`, `max_deliver: 5`).
- [x] 3.2 Document the reserved subject prefixes in `openspec/specs/messaging-runtime/subject-reservations.md`: `rbrain.<ctx>.*` for context-published events, `rbrain.system.*` reserved for `deploy`.
- [x] 3.3 Write `scripts/validate-subjects.sh` that scans every repo's `OWNERSHIP.publishes` and asserts each subject matches `^rbrain\.([a-z-]+)\.([a-z][a-z0-9-]*)$` with the first segment being the publishing context (or `system` only for `deploy`).

## 4. llm-abstraction capability

- [x] 4.1 Document the `LlmPort` capability contract in `openspec/specs/llm-abstraction/llm-port.md` (the three required capabilities — generation, tool-calling, embeddings — as prose, without method signatures).
- [x] 4.2 List the three reference providers and their accepted env var sets in `openspec/specs/llm-abstraction/providers.yaml` (`claude`: `ANTHROPIC_API_KEY`, optional `ANTHROPIC_BASE_URL`, `ANTHROPIC_MODEL`; `ollama`: `OLLAMA_BASE_URL`, `OLLAMA_MODEL`; `openai`: `OPENAI_API_KEY`, optional `OPENAI_BASE_URL`, `OPENAI_MODEL`).
- [x] 4.3 Document the no-default-provider rule and the boot-time failure expectation in `openspec/specs/llm-abstraction/boot-validation.md`.
- [x] 4.4 Write `scripts/validate-llm-config.sh` that asserts `providers.yaml` lists exactly three providers and that each lists at least one required env var.

## 5. Cross-capability follow-up

- [x] 5.1 Update `rbrain-codex/README.md` to point newcomers at the three new entry-point files (`runtime-allocation.yaml`, `memory-budgets.yaml`, `providers.yaml`) alongside the existing `catalog.yaml` and `sync-graph.yaml`.
- [x] 5.2 Update `rbrain-codex/AGENTS.md` to mention the new validators and how to run them locally.

## 6. Hand-off

- [x] 6.1 Confirm CI runs all six validators (`validate-catalog`, `validate-topology`, `validate-repo`, `validate-runtimes`, `validate-data-stores`, `validate-subjects`, `validate-llm-config`) on push and PR.
- [ ] 6.2 Archive this change via `openspec archive technology-stack` once tasks 1.x–5.x are complete and CI is green.
