## MODIFIED Requirements

### Requirement: Authoritative synchronous call graph

The platform SHALL maintain an authoritative synchronous call graph at `openspec/specs/service-topology/sync-graph.yaml` listing every allowed HTTP edge between contexts as `(caller, callee, purpose)`. The graph SHALL contain exactly the following edges and no others:

- `app → gateway` — all frontend traffic
- `gateway → identity` — authentication and account operations
- `gateway → cortex` — chat and agent invocations
- `gateway → chronicle` — blog content reads and edits
- `gateway → forge` — user-scoped deck CRUD (deck storage and retrieval)
- `cortex → lexicon` — card lookups used as agent tools
- `cortex → oracle` — rules queries used as agent tools
- `cortex → forge` — deck operations used as agent tools

`forge` is intentionally **dual-role**: it is both a cortex agent-tool backend (parse/analyze) and a gateway-fronted CRUD backend (it owns user decks). This is the one backend the gateway calls directly that is also a cortex tool; it is permitted because forge owns user data (decks), not merely derived tool answers.

Any new synchronous call between contexts SHALL be added to this graph via an OpenSpec change before implementation.

#### Scenario: Unlisted edge is forbidden

- **WHEN** a developer attempts to add an HTTP call from `chronicle` to `lexicon`
- **THEN** the call SHALL be rejected by code review or CI policy because the edge `chronicle → lexicon` is not in `sync-graph.yaml`

#### Scenario: Pure tool service is not directly callable from gateway

- **WHEN** the gateway receives a request that would require card data
- **THEN** the gateway SHALL route the request to `cortex`, and `cortex` SHALL call `lexicon`; the gateway SHALL NOT call `lexicon` directly (lexicon and oracle remain cortex-only tool backends)

#### Scenario: Gateway may call forge for deck CRUD

- **WHEN** an authenticated user saves or reads a deck
- **THEN** the gateway MAY proxy the request directly to `forge` (the `gateway → forge` edge), because deck storage is user data forge owns, distinct from forge's cortex-tool role
