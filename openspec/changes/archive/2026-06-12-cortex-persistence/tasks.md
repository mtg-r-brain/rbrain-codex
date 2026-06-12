## 1. Codex spec authorship

- [x] 1.1 Draft MODIFIED requirement "Schema ownership per bounded context" in `data-stores/spec.md` — add `cortex` to the list + new scenarios for cortex ownership and the postgres-roles registry presence
- [x] 1.2 `openspec validate cortex-persistence --strict` clean

## 2. Codex configuration updates (apply phase, codex side)

- [x] 2.1 Update `openspec/specs/data-stores/postgres-roles.yaml`: add `cortex` entry with schema `cortex`, full DML privileges, `superuser: false`, `cross_schema: []`
- [x] 2.2 Update `openspec/specs/data-stores/postgres-baseline.md`: add `CREATE SCHEMA IF NOT EXISTS cortex;` to the bootstrap SQL block; remove the parenthetical "though `cortex` is not in this list because it owns no schema" (line ~41) which becomes false
- [x] 2.3 Update `scripts/validate-data-stores.sh`: extend `EXPECTED_ROLES` from `(identity lexicon oracle forge chronicle)` to include `cortex`; the header comment goes from "five persistent contexts" to "six" — the validator's contract has to track the spec list
- [ ] 2.4 Commit codex apply: `📝 docs(cortex-persistence): list cortex schema/role in postgres-roles + baseline`

## 3. Codex CI

- [ ] 3.1 Push the 4 planning commits + the apply commit; verify codex CI workflow goes green (7 validators + scaffold-drift)

## 4. Cortex code — Alembic infrastructure

- [x] 4.1 Add `asyncpg >= 0.30` and `alembic >= 1.13` to `rbrain-cortex/pyproject.toml`; `uv sync`
- [x] 4.2 Add `rbrain-cortex/alembic.ini` (script_location = `alembic`, file_template, version_locations)
- [x] 4.3 Add `rbrain-cortex/alembic/env.py` configured for async migrations (asyncpg engine, `run_migrations_online()` async pattern); reads `DATABASE_URL` from env
- [x] 4.4 Add `rbrain-cortex/alembic/script.py.mako` (standard Alembic template, raw SQL via `op.execute`)
- [x] 4.5 Add `rbrain-cortex/alembic/versions/0001_create_conversations.py`:
  - `op.execute("CREATE SCHEMA IF NOT EXISTS cortex")`
  - `op.execute("""CREATE TABLE cortex.conversations (id uuid PRIMARY KEY, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), messages jsonb NOT NULL DEFAULT '[]'::jsonb)""")`
  - downgrade drops the table and (optionally) the schema if empty

## 5. Cortex code — PostgresConversationStore

- [x] 5.1 Add `rbrain-cortex/app/chat/db.py` exposing `create_pool(database_url: str) -> asyncpg.Pool` + a `ping(pool) -> None` that runs `SELECT 1` for boot validation
- [x] 5.2 Refactor `rbrain-cortex/app/chat/store.py`: extract an abstract `ConversationStore` interface (5 methods: `new_conversation`, `exists`, `append`, `extend`, `fetch`) that both `InMemoryConversationStore` (existing, unchanged behavior) and the new `PostgresConversationStore` implement
- [x] 5.3 Implement `PostgresConversationStore` in `app/chat/store.py` (or split into `app/chat/postgres_store.py`):
  - `new_conversation`: INSERT into cortex.conversations with a fresh UUID4, return the id
  - `exists`: SELECT 1 FROM cortex.conversations WHERE id = $1
  - `append`: UPDATE cortex.conversations SET messages = messages || jsonb_build_array($2::jsonb), updated_at = now() WHERE id = $1 — atomically appends one message
  - `extend`: same as append but the jsonb cast is `jsonb` of the array of new messages
  - `fetch`: SELECT messages FROM cortex.conversations WHERE id = $1; parse JSONB into `list[Message]`
- [x] 5.4 Update `rbrain-cortex/app/main.py`:
  - Read `DATABASE_URL` from env; missing or unparseable → exit 78 (EX_CONFIG)
  - Create asyncpg pool; `ping()` it
  - Run Alembic `upgrade head` programmatically (or document the manual step if programmatic invocation is fragile)
  - Wire `PostgresConversationStore` into `app.state.conversation_store`
  - Bind the HTTP port last

## 6. Cortex code — local dev fixture

- [x] 6.1 Add `rbrain-cortex/docker-compose.yaml` with one `postgres:16` service on host port `5433` (distinct from lexicon's `5432`); volume mount under `./.data/postgres-cortex`; database `cortex`, role `cortex` (POSTGRES_USER/PASSWORD), password from env or hardcoded for dev
- [x] 6.2 Add a `.env.example` line for `DATABASE_URL=postgresql://cortex:cortex@localhost:5433/cortex`

## 7. Cortex tests

- [x] 7.1 Update `tests/test_chat_endpoint.py` and `tests/test_agent_loop.py` to inject the `InMemoryConversationStore` via the abstract interface (or keep the existing wiring — likely no change needed since tests already use `InMemoryConversationStore` directly)
- [x] 7.2 Add `tests/test_postgres_store.py` integration tests:
  - Skip the file if `DATABASE_URL` is not set in the test env, or use testcontainers (`testcontainers[postgresql]`) to spin up an ephemeral PG for the test session
  - Cover: new_conversation returns a fresh UUID; append + fetch round-trip preserves message order; extend appends multiple at once; exists returns true after new_conversation; restart-resilience asserted by closing the pool and reopening
- [x] 7.3 Add `tests/test_boot.py` cases:
  - Missing `DATABASE_URL` exits 78
  - `DATABASE_URL` with bad scheme exits 78
- [x] 7.4 `uv run ruff check . && uv run ruff format --check . && uv run mypy app && uv run pytest -x` all green

## 8. Cortex CI

- [x] 8.1 Update `rbrain-cortex/.github/workflows/ci.yml` to start a Postgres service block (PG 16 image, expose 5432 in the runner; matches lexicon's pattern minus NATS); set `DATABASE_URL` env for the pytest step
- [x] 8.2 Push the cortex commit(s); verify cortex CI workflow goes green

## 9. cortex-bootstrap MODIFIED follow-up (in rbrain-cortex)

- [ ] 9.1 In `rbrain-cortex/openspec/specs/cortex-bootstrap/spec.md`, the requirement "In-memory conversation store is async-safe" needs an update so the production wiring uses `PostgresConversationStore`. This is a cortex-side spec change tracked by a separate cortex change (NOT by this codex change). File a follow-up change `cortex-persistence-store-interface` in rbrain-cortex once this codex change is archived. _Deferred: tracked, not blocking the codex archive._

## 10. Archive and handoff

- [ ] 10.1 Run `/opsx:archive cortex-persistence` in codex to promote the MODIFIED delta into `openspec/specs/data-stores/spec.md`
- [ ] 10.2 Push the archive commit; verify codex CI stays green
- [ ] 10.3 Update the platform handoff drawer in MemPalace marking ticket #4 done; queue ticket #5 (new sibling choice) and the cortex-bootstrap follow-up
