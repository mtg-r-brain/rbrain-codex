## Context

Cortex's conversation state today lives in `InMemoryConversationStore`: an `asyncio.Lock`-guarded dict keyed by conversation UUID, value is a list of `Message`. The store's lifetime equals the process lifetime; restart wipes everything. `cortex-bootstrap` ratified this as a v1 simplification.

The platform's persistent storage doctrine is in `data-stores`:

- Single PostgreSQL 16 instance, pgvector extension.
- One schema per persistent BC, owned by a role with DML grants on that schema only.
- Redis explicitly rejected as a primary store ("MUST survive a cache flush or instance restart" → SHALL be in Postgres).
- Migrations per-context (SQLx for Rust, Alembic for cortex), applied at service start.
- Cross-schema reads forbidden at the database layer.

Lexicon's implementation establishes the precedent: a single schema (`lexicon`), SQLx migrations in `migrations/`, a `docker-compose.yaml` for local dev (PG 16 + NATS), a service role configured externally (`rbrain-deploy` in prod, the dev DB defaults for local).

The 2026-06-12 evening session ships cortex's analogue: schema `cortex`, Alembic migrations under `alembic/versions/`, asyncpg-based store implementation, `docker-compose.yaml` for cortex's local PG. The wire shape (`POST /chat` request/response) is untouched — the change is purely about state durability.

## Goals / Non-Goals

**Goals:**

- Add `cortex` as the 6th persistent BC in `data-stores`, with its own schema and role, following the platform's existing per-BC isolation discipline.
- Ship a `PostgresConversationStore` that conforms to the same `ConversationStore` interface as `InMemoryConversationStore` (tests can swap implementations; production uses Postgres).
- Conversations survive cortex restarts. A `POST /chat` with a known `conversation_id` continues from the persisted history.
- Conversations table schema is minimal and JSON-anchored: one row per conversation, messages as JSONB. Keep the schema shape easy to evolve (single column to migrate as the message model grows).
- Boot-time validation matches the `llm-abstraction` pattern: missing `DATABASE_URL` → exit 78 (EX_CONFIG) before binding the HTTP port; migrations applied before serving.
- Cortex's local dev gets its own `docker-compose.yaml` mirroring lexicon's pattern (same PG 16 image; same isolation discipline; not sharing the lexicon compose file because each sibling owns its dev fixture).

**Non-Goals:**

- Schema sharing across BCs. Cortex's schema is isolated; no cross-schema reads from cortex into lexicon or vice versa.
- Per-message-row persistence. Conversations stay as one JSONB blob; the table is `(id uuid PK, created_at, updated_at, messages jsonb)`. Per-message rows would inflate the migration matrix without buying anything for v1.
- SQLAlchemy ORM. The platform's frugality target (~786 MB across siblings) and cortex's 200 MB ceiling argue for raw asyncpg + Alembic-with-raw-SQL.
- Connection pool tuning. asyncpg's default pool (min 10, max 10) is fine for v1; revisit when load profile is real.
- Message-level encryption at rest. Not in scope; rely on disk encryption at the deploy layer once production exists.
- Multi-tenant conversation isolation (per user). Cortex doesn't have a user model yet — identity slice owns that. Future change adds a `user_id` column under a foreign-key constraint to the `identity` schema (which is a cross-schema *reference*, not a cross-schema *query*; the FK is a schema-level guarantee, not a runtime read).
- Read-only replicas for analytics. Out of scope.
- Conversation TTL / garbage collection. Out of scope for v1; the table grows monotonically. Future change adds a retention policy if storage becomes a concern.

## Decisions

### Decision 1: Conversations as one JSONB blob per row, not per-message rows

**Choice:** `cortex.conversations(id uuid PK, created_at timestamptz, updated_at timestamptz, messages jsonb NOT NULL)`. The `messages` column carries an array of message objects with the same shape as `app/llm/types.Message`.

**Rationale:** Three reasons:

1. **Schema mobility.** The `Message` model is still evolving (tool_calls field added recently; refusals likely next). A JSONB column absorbs those changes without requiring a migration each time. Per-message rows would force schema migrations for every Message field added.
2. **Read pattern is whole-conversation.** Every cortex turn reads the entire conversation history into memory to prompt the LLM; there's no per-message query at v1. Storing per-message rows would mean an extra `ORDER BY position` query and an array reassembly on every turn, with no query the per-row schema enables.
3. **Atomic appends.** A turn appends one assistant message + zero-or-more tool messages atomically. With a JSONB blob, the append is `UPDATE conversations SET messages = messages || $1, updated_at = now() WHERE id = $2` — one statement, transactional by construction.

**Alternatives considered:**

- **Per-message rows (`cortex.messages(conversation_id fk, position int, role, content, tool_call_id, ...)`)**: rejected. Inflates the migration surface for every Message field; offers no v1 query advantage.
- **Hybrid (conversations table + denormalised cache of latest_message)**: rejected. Premature optimisation; the JSONB read is fast enough.

### Decision 2: asyncpg, not SQLAlchemy ORM

**Choice:** `asyncpg.create_pool()` directly. Alembic is used with raw-SQL migrations (`op.execute("...")`), not its autogenerate / declarative model machinery.

**Rationale:**

1. **Frugality.** SQLAlchemy adds ~25-40 MB of in-process memory at boot (importable graph plus metadata). Cortex's 200 MB ceiling is real and asyncpg-only keeps headroom for the LLM SDKs (anthropic / openai are non-trivial).
2. **Cortex's query surface is small.** Four operations exist: `new_conversation`, `append`, `extend`, `fetch`, `exists`. Each fits in a 1-2 line SQL statement; no ORM-style traversals or complex joins to motivate the abstraction.
3. **Migration discipline.** Raw SQL migrations are explicit about what runs at deploy time — important because cortex's migrations will eventually run against a shared cluster.

**Alternatives considered:**

- **SQLAlchemy ORM**: rejected for the reasons above. The "we might need ORM features later" hypothetical doesn't justify the memory cost or the abstraction overhead today.
- **psycopg3 async**: rejected — asyncpg is faster (per its own benchmarks) and lexicon's Rust analogue (`sqlx`) has a similar low-level character.
- **SQLModel**: same memory profile as SQLAlchemy; rejected for the same reasons.

### Decision 3: Migration owns `CREATE SCHEMA cortex` (idempotent)

**Choice:** Alembic migration `0001_create_conversations.py` opens with `CREATE SCHEMA IF NOT EXISTS cortex;` then proceeds to create `cortex.conversations`. The platform contract (`postgres-baseline.md`) says `rbrain-deploy` provisions schemas at bootstrap, but `rbrain-deploy` doesn't exist yet. The idempotent `IF NOT EXISTS` means the migration is safe in both worlds:

- Local dev (no rbrain-deploy): migration creates the schema.
- Production (rbrain-deploy provisions schemas first): migration finds the schema already there, no-ops on that statement, proceeds to the table.

**Rationale:** Cortex's pattern mirrors lexicon's: lexicon's migration 0001 creates its `lexicon.card` table without creating the schema (lexicon's `docker-compose.yaml` PG init handles it), but cortex's `docker-compose.yaml` PG init shouldn't carry a hardcoded schema list (drift risk if the per-BC list grows). Putting the `CREATE SCHEMA IF NOT EXISTS` in the cortex-owned migration keeps the bootstrap declarative and per-context.

The data-stores requirement says "rbrain-deploy provisions schemas". This change does not violate it — `rbrain-deploy` will still do that in production. The cortex migration is defence-in-depth, not a replacement.

**Alternatives considered:**

- **docker-compose `init.sql` script**: rejected. Spreads the schema declaration across cortex's dev fixture *and* rbrain-deploy's prod scripts. Two sources of truth.
- **A migration-only `CREATE SCHEMA` step, no IF NOT EXISTS**: rejected. Production rbrain-deploy creates the schema first → migration would fail with "schema already exists" at deploy.

### Decision 4: Cortex's `docker-compose.yaml` is independent from lexicon's

**Choice:** `rbrain-cortex/docker-compose.yaml` ships its own PG 16 container on a different host port (e.g., 5433 vs lexicon's 5432) and a different volume mount. No service mesh, no shared volumes, no env-var sharing.

**Rationale:** Each sibling owns its dev fixture. The schemas are isolated by role in production; locally the cheapest way to enforce the same isolation is one Postgres per repo during dev. Cross-BC tests (gateway integration, e2e) will eventually need a shared local cluster — that's a `rbrain-deploy`-tier concern, not something this slice should pre-commit to.

**Alternatives considered:**

- **Cortex reuses lexicon's compose file**: rejected. Forces a clone-order dependency (cortex devs must clone lexicon first), and mixes per-sibling isolation into a single host port range.
- **A platform-wide compose file in `rbrain-deploy`**: deferred — rbrain-deploy doesn't exist yet. When it does, cortex's standalone compose remains valid for solo work and the platform-wide file becomes the integration story.

### Decision 5: `DATABASE_URL` is required at boot; fast-fail on missing

**Choice:** Same pattern as `LLM_PROVIDER` and `LEXICON_URL`: missing or unparseable `DATABASE_URL` → exit 78 (EX_CONFIG) before binding the HTTP port. Migrations applied between connection check and HTTP bind.

**Rationale:** Aligns with the existing `llm-abstraction` boot discipline cortex already implements. Failing fast is preferable to lazy connections that surface as 500s mid-traffic.

The boot sequence becomes:

1. Validate `LLM_PROVIDER` + provider env vars (existing).
2. Validate `LEXICON_URL` (existing).
3. Validate `DATABASE_URL` (new).
4. Open the asyncpg pool; ping (`SELECT 1`).
5. Run Alembic `upgrade head`.
6. Bind the HTTP port.

Any step's failure exits 78 (configuration) or 70 (software, for migration failure post-config — distinct so ops can triage).

## Risks / Trade-offs

- **[Risk] JSONB column makes per-message indexing impossible** → Mitigation: not needed at v1. If a use case emerges (e.g., "find all conversations that called `lookup_card`"), the JSONB GIN index can be added in a follow-up migration without restructuring.

- **[Risk] Migration races across multiple cortex instances at deploy time** → Mitigation: Alembic's `alembic_version` table + advisory lock pattern is well-trodden. asyncpg has `pg_advisory_lock`; the migration runner acquires it before applying.

- **[Trade-off] No conversation TTL** → Accepted for v1. The table grows monotonically. Conversations are small (median ~5-20 messages, each a few KB JSONB). At 1k turns/day with average 10 messages × 1 KB = 10 MB/day. A retention policy can be a future MODIFIED.

- **[Risk] Restart during a long ReAct loop loses in-flight state** → Accepted. Cortex commits the assistant + tool messages to the store *after* the loop terminates, not per-iteration. A restart mid-loop loses the current turn but preserves the prior history. That's the same failure mode as the in-memory store; the persistence change doesn't worsen it. A future "checkpoint per iteration" change could harden it.

- **[Trade-off] Two implementations of `ConversationStore` to maintain (InMemory + Postgres)** → Accepted. InMemory is a 20-line test fixture; the maintenance burden is negligible. The alternative (only Postgres, tests spin up a real PG via testcontainers) inflates the unit-test runtime and makes dev iteration slower.

- **[Risk] Cortex CI gains a Postgres service block; the workflow gets longer** → Accepted. Lexicon already runs with PG in CI (~30s overhead). Cortex follows the same pattern.

## Open Questions

None. The data-stores doctrine is decided; the JSONB-blob choice is defensible by today's read pattern; the asyncpg/Alembic stack is small enough to ship in one sitting.
