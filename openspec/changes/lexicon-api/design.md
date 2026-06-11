## Context

`rbrain-codex` has so far carried platform-level contracts (bounded contexts, topology, conventions, stack, scaffold). After `card-storage-mvp` shipped in `rbrain-lexicon`, the platform now has its first cross-context HTTP edge exercised by real code, but the **shape** of that edge has no contract in codex. This change introduces a new family of capabilities — per-sibling `<context>-api` — to hold those shapes.

Stakeholders: the maintainer (sole author), `rbrain-lexicon` (the sibling whose contract this captures), and `rbrain-cortex` (the eventual consumer that will reference this spec when implementing the agent tool that calls `/cards/{id}`).

## Goals / Non-Goals

**Goals:**

- Lock the shape of `GET /cards/{scryfall_id}` so future drift on the lexicon side is a deliberate, OpenSpec-tracked event.
- Establish the **convention** for per-sibling public-API specs — naming, scope, where they live — so the remaining seven public-facing siblings follow the same pattern.
- Keep the spec aligned 1:1 with what lexicon actually ships today. No aspirational endpoints, no NATS events that don't exist yet.

**Non-Goals:**

- Generating an OpenAPI document or any machine-checkable schema from the spec. Markdown requirements are enough at this scale; tooling lands when a real consumer (cortex) needs it.
- Building a codex-side validator that exercises lexicon's running service. The lexicon CI already runs `cargo test` on the handler; cortex CI will fail when its client drifts from the contract. No third enforcement point at v1.
- Documenting future endpoints (search, list-by-set, batch lookup). They land via MODIFIED deltas when lexicon implements them.
- Documenting NATS event subjects. They land when the lexicon sync slice publishes them.

## Decisions

### D1. Per-sibling umbrella capability `<context>-api`

A new capability `lexicon-api` is introduced in codex. Future endpoints from `rbrain-lexicon` go into the same spec via MODIFIED deltas. The pattern repeats per sibling: `oracle-api`, `forge-api`, `identity-api`, `chronicle-api`, `cortex-api` (for the chat/agent HTTP surface), `gateway-api` (for the public surface). `deploy-api` and `codex-api` do not exist (no public HTTP surface).

**Rationale:** A capability spec evolves over time; a per-sibling umbrella tracks the natural unit of evolution (the sibling's API surface) rather than fragmenting into one capability per endpoint family. Querying "what does lexicon expose?" is a single-file read.

**Alternatives considered:**

- **Per use-case capabilities** (`card-lookup-api`, `card-search-api`, etc.) — rejected: fragments the surface, makes "show me lexicon's whole API" a multi-file gather, and forces a naming decision at endpoint-add time.
- **Single platform-wide `public-api` capability** — rejected: bundles every sibling's contract in one file, kills locality.

### D2. Scope mirrors what's shipped, nothing more

This v1 spec captures only `GET /cards/{scryfall_id}` because that is the only endpoint lexicon ships. Forward-looking sketches (planned endpoints, future event subjects) are explicitly excluded.

**Rationale:** A spec that promises endpoints that don't exist trains consumers to write code against vapor. Better to add the endpoint to the spec the same day lexicon ships it.

**Alternatives considered:**

- **Include a "planned" section** — rejected: future planning lives in `openspec/changes/` (open or unopened), not in the live contract.

### D3. Card payload shape lives in `lexicon-api`, not in a shared `card-model` capability

The six-field card structure is declared inside `lexicon-api`. There is intentionally no top-level shared `card-model` capability at v1 — lexicon is the only context that emits Card structures, so the shape belongs to lexicon's contract.

**Rationale:** Premature shared models force every consumer to import a centrally defined type even when the consumer only needs three of six fields. Keeping the shape inside `lexicon-api` lets future consumers project just what they need.

**Alternatives considered:**

- **Define `card-model` shared capability** — rejected: speculative. If a second context ever publishes Card structures with the same fields (Forge maybe surfacing a parsed deck list with full card metadata?), we extract then.

### D4. No codex-side runtime validator

The spec is enforced by two existing CI surfaces:

- `rbrain-lexicon`'s CI runs `cargo test`, which exercises the actual handler against both happy and 404 paths.
- `rbrain-cortex`'s CI will (in a later slice) run a contract test or mock against the shape declared here.

No codex CI step diffs lexicon's responses against the spec. The cost of running lexicon in codex CI to assert the contract is disproportionate to the risk at v1.

**Rationale:** Pragmatism. We can introduce a contract test runner when consumer count > 1 or when drift bites in practice.

**Alternatives considered:**

- **Add a Pact-style consumer contract test in cortex** — accepted as future work, not v1.
- **Run lexicon in codex CI and curl `/cards/{id}`** — rejected: bring up a Postgres-less lexicon in CI requires extra wiring; doesn't pay off until we have multiple consumers.

### D5. Response examples carry concrete JSON

Every requirement that defines a response shape SHALL include at least one concrete JSON example matching the shipped behavior (e.g., the Black Lotus 200 payload, the 404 echo). Examples are part of the spec, not decoration.

**Rationale:** Schemas are abstract; examples are testable in the reader's head. A future cortex implementer needs to see exact byte sequences.

## Risks / Trade-offs

- **Spec/code drift inside lexicon's own boundary.** → Mitigation: lexicon's tests cover the same shape and run on every PR. If the spec changes but lexicon doesn't, codex CI doesn't catch it — but the next time cortex's contract test runs, it does. Accept the gap until cortex ships.
- **Premature convention freeze on `<context>-api` naming.** → Mitigation: if a sibling later ships multiple distinct surfaces (e.g., a public HTTP API and an internal admin API), we can split into `<context>-public-api` / `<context>-admin-api` then. The pattern is revisable.
- **Card payload duplication if another context emits cards.** → Mitigation: extract a `card-model` capability with a MODIFIED delta on `lexicon-api`. Cost is one OpenSpec change.

## Migration Plan

No migration. This change adds a new capability spec to codex. No code change in any sibling. No runtime impact.

## Open Questions

- **JSON content-type header**: lexicon returns `application/json` today (axum's `Json` default). Should the spec name the exact MIME or stay generic? — Decision in specs: name it (`application/json`), so cortex doesn't have to discover it via trial.
- **`scryfall_id` format constraints**: the spec leaves the path parameter as an opaque string at v1 (lexicon does the same). If we later want to reject non-UUID inputs at the gateway level, the constraint goes into `gateway-api` (when that ships), not here.
- **Versioning**: `/cards/{id}` is unversioned. When the second endpoint family lands and we have to think about breaking changes, the decision (`/v1/` prefix vs. header vs. major-only breaking changes) gets its own OpenSpec change against `gateway-api` or `lexicon-api`.
