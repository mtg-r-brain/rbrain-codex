## Why

Cortex's `InMemoryConversationStore` was a deliberate v1 simplification: the `cortex-bootstrap` spec ratified it, and the agent-loop slice prioritised getting an end-to-end `POST /chat` working. The cost was acknowledged at the time: restart wipes every conversation. That's unacceptable for any consumer beyond a developer poking at the local stack:

- A future `rbrain-gateway` proxy can't recover from a cortex restart without losing user context.
- A future `rbrain-app` chat UI's "continue this conversation" button would silently break across deployments.
- Operational diagnostics (replaying a misbehaving turn, auditing tool invocations) require the conversation to outlive the process.

The platform's data-stores capability already mandates the durable side: PostgreSQL is the sole relational store, every persistent BC owns exactly one schema, Redis is explicitly rejected for restart-surviving data. The schema list — `identity, lexicon, oracle, forge, chronicle` — does NOT include `cortex` because cortex was non-persistent at v1. This change closes that gap.

The deferred fork from yesterday's planning ("DB shared with lexicon vs own DB?") is resolved by the existing spec: same Postgres instance, **own schema**, isolated via per-context role + DML grants restricted to the owning schema. No new architectural decision needed; we apply the doctrine that's already on disk.

## What Changes

- MODIFY `data-stores`/"Schema ownership per bounded context" requirement to add `cortex` to the persistent-BC list. The list becomes `{identity, lexicon, oracle, forge, chronicle, cortex}`.
- UPDATE `openspec/specs/data-stores/postgres-roles.yaml` to add the `cortex` role (schema `cortex`, DML grants, no superuser, no cross-schema).
- UPDATE `openspec/specs/data-stores/postgres-baseline.md` to:
  - Add `cortex` to the schema bootstrap list.
  - Remove the parenthetical "though `cortex` is not in this list because it owns no schema" (which becomes false).
- MODIFY `cortex-bootstrap` (in `rbrain-cortex`) requirement "In-memory conversation store is async-safe" → renamed/extended to specify a durable, async-safe `ConversationStore` interface with two implementations: `InMemoryConversationStore` (tests only) and `PostgresConversationStore` (production). Restart-preservation becomes mandatory in production wiring.
- IMPLEMENT in `rbrain-cortex`:
  - Alembic infrastructure (`alembic.ini`, `alembic/env.py` async, `alembic/versions/` folder).
  - First migration creates the `cortex` schema (idempotent for dev convenience — production gets `CREATE SCHEMA` from `rbrain-deploy`) and the `cortex.conversations` table.
  - `PostgresConversationStore` using `asyncpg` directly (no SQLAlchemy ORM, aligned with the platform frugality target: ~786 MB).
  - `DATABASE_URL` env var, required at boot per the `llm-abstraction` pattern (missing → EX_CONFIG 78).
  - Migrations applied at service startup (per the existing data-stores requirement "Migration applies at boot").
  - Integration tests via testcontainers OR a `docker-compose.yaml` for cortex's own PG (cortex doesn't reuse lexicon's compose file — each sibling owns its dev fixture).

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `data-stores`: MODIFIED requirement "Schema ownership per bounded context" to include cortex as the sixth persistent BC. The companion configuration files `postgres-roles.yaml` and `postgres-baseline.md` are updated in the same change.

## Impact

- **Code (rbrain-cortex)**:
  - New: `alembic.ini`, `alembic/env.py`, `alembic/versions/0001_create_conversations.py` (or `.sql`), `app/chat/store.py` gets a `PostgresConversationStore` class alongside `InMemoryConversationStore`, `app/chat/db.py` (asyncpg pool factory), `app/main.py` boot validation for `DATABASE_URL`, `docker-compose.yaml` for cortex's local PG, `tests/test_postgres_store.py` integration tests.
  - Modified: `app/main.py` (wires Postgres store in production path; dependency injection point), `app/chat/store.py` (interface formalisation if needed), `pyproject.toml` (add `asyncpg`, `alembic` dependencies).
- **Code (rbrain-codex)**: spec.md + postgres-roles.yaml + postgres-baseline.md only.
- **APIs**: no wire change. `POST /chat` shape unchanged. The `conversation_id` semantic gains durability: a known id remains known across cortex restarts.
- **Dependencies**: cortex adds `asyncpg >= 0.30` and `alembic >= 1.13`. Both small, mature, async-friendly.
- **Memory budget**: ~5-10 MB additional baseline (asyncpg connection pool + Alembic at boot). Cortex's 200 MB ceiling has comfortable headroom.
- **Specs touched**: codex `data-stores` (MODIFIED); cortex `cortex-bootstrap` MUST be updated via a follow-up cortex-side commit referencing this change (pattern: ollama-cloud-auth).
- **Migration**: existing local dev sessions lose their in-memory conversations (acceptable — dev only). Production has nothing to lose yet.
- **Cortex CI**: needs a Postgres service block (matching lexicon's `ci.yml` pattern, minus the NATS quirk).
- **Validators**: `scripts/validate-data-stores.sh` (codex CI) iterates over `postgres-roles.yaml` — adding `cortex` to the file is enough; no validator code change.
