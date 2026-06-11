## Context

MTG R.brain is a greenfield project. The founding documents (`ideas/01-project-vision.md`, `ideas/02-repositories.md`, `ideas/03-stack.md`) declare the product scope (rules agent, deck agent, chat, blog, accounts), the intent to split the system across 10 bounded contexts, and a frugality constraint (~786 MB total RAM target). No code exists yet; no infrastructure is provisioned. This change formalizes the architectural contract that all subsequent specs and repository scaffolding will anchor on.

The stakeholders for this design are: the maintainer (sole author at this stage), future contributors who will need a stable contract to onboard against, and AI agents (this one and siblings) that will operate on multiple repositories and need consistent conventions to navigate them.

## Goals / Non-Goals

**Goals:**

- Define a single, authoritative source of truth for "which repo owns what" — eliminate ambiguity before it produces overlapping or orphan responsibilities.
- Lock down the inter-context communication graph so that emergent coupling is detected as a contract violation, not absorbed silently.
- Establish baseline repository conventions strong enough that tooling (CI templates, deploy automation, agents) can treat any `rbrain-*` repo uniformly.
- Keep the design revisable: this is the v1 contract, not the eternal one. Subsequent OpenSpec changes can amend it.

**Non-Goals:**

- Justifying the technology stack (Rust / Python / Next.js / pgvector / NATS) — that belongs to the future `technology-stack` spec; this design only cites stack choices where they determine a topology decision.
- Defining the behavior of any individual capability (rules agent, deck agent, etc.) — those are their own specs.
- Prescribing the internal architecture of each context (folder layout inside a Rust service, module structure of the Python orchestrator) — only the external contract is in scope here.
- Detailing CI/CD pipelines, secret management, or observability — those are deployment concerns, addressed in `deployment-topology`.

## Decisions

### D1. Ten bounded contexts, one repository per context

The 10 contexts (`gateway`, `identity`, `lexicon`, `oracle`, `forge`, `cortex`, `chronicle`, `app`, `deploy`, `codex`) map 1:1 to repositories.

**Rationale:** Each context has a distinct domain language (cards vs. rules vs. decks vs. conversations) and a distinct release cadence (the card catalogue rebuilds nightly; the agent orchestrator changes weekly; the blog changes ad-hoc). Polyrepo gives each context its own CI pipeline, its own versioning, and its own deploy lifecycle without cross-blocking. Monorepo would force shared CI infrastructure and tighter coupling at the build layer — exactly what the DDD split is meant to prevent.

**Alternatives considered:**

- **Monorepo with workspace tooling** (Nx, Turborepo, Bazel) — rejected: adds tooling complexity disproportionate to the project's scale, and the polyglot stack (Rust + Python + TS) makes a unified build graph painful.
- **Fewer, larger contexts** (e.g., merge `lexicon` into `oracle`, merge `forge` into `cortex`) — rejected: collapses domain languages that should stay separate. The card catalogue is a static reference dataset; the rules engine is a reasoning system. Merging them couples sync schedules and inflates the service.

### D2. Gateway is the single ingress; backend services are not directly exposed

`rbrain-app` (frontend) calls `rbrain-gateway` only. The gateway routes to `identity`, `cortex`, and `chronicle`. Other backend services (`lexicon`, `oracle`, `forge`) are reachable only from within the cluster — they are tools invoked by `cortex`, not public APIs.

**Rationale:** A single ingress is the obvious place to centralize auth, rate limiting, and observability. Exposing each backend service directly would scatter that concern across 7 surfaces and prevent uniform policy enforcement.

**Alternatives considered:**

- **Service mesh with per-service ingress** (Istio, Linkerd) — rejected: enormous operational overhead, runs counter to the frugality constraint.
- **Frontend talks directly to identity and cortex** (skip gateway for some routes) — rejected: splits the auth surface and complicates the frontend's network code.

### D3. Synchronous HTTP for command paths, asynchronous NATS for events

- Frontend → gateway → backend: synchronous HTTP (REST or streaming for chat).
- Cortex → tool services (lexicon, oracle, forge): synchronous HTTP.
- Cross-context notifications (e.g., a new card released in lexicon, a deck saved in forge that other contexts may want to observe): asynchronous NATS JetStream events.

**Rationale:** Synchronous for request-response paths where the caller needs the answer immediately (chat turn, card lookup). Asynchronous for fan-out notifications where the producer should not be coupled to the consumer's availability. NATS JetStream gives at-least-once delivery with replay, which is enough for the integration patterns identified so far.

**Alternatives considered:**

- **All synchronous HTTP** — rejected: couples producers to consumers' availability; a future analytics consumer of "deck saved" events would force `forge` to know about it.
- **Kafka instead of NATS** — rejected on memory footprint (~512 MB vs. ~40 MB); Kafka's ordering guarantees are not required at this scale.

### D4. `rbrain-codex` is itself a bounded context

The codex repo holds specs, ADRs, and the OpenSpec workflow. It is listed as the 10th BC because it has a domain (architectural decisions), a vocabulary (specs, proposals, capabilities), and a lifecycle (changes flow through proposal → specs → design → tasks → archive). Treating it as a BC gives it the same conventions and discipline as code-bearing contexts.

**Rationale:** Without this, the spec repo would drift into ad-hoc conventions ("where do we put the new ADR?", "what's the file naming for proposals?"). Codex as a BC inherits `repository-conventions` and provides a uniform contributor experience.

**Alternatives considered:**

- **Treat codex as infrastructure, not a BC** — rejected: it would escape the conventions everyone else must follow, creating an asymmetric contributor experience.

### D5. Repository conventions are mandatory, minimal, tool-enforceable

Every `rbrain-*` repo MUST ship: a `README.md`, an `AGENTS.md`, a CI manifest, and an ownership metadata file (TBD format — likely YAML at the root). Beyond that, internal structure is left to each context.

**Rationale:** Conventions earn their keep when tooling can rely on them. A mandatory `AGENTS.md` lets any AI agent bootstrap into any repo with the same protocol. A mandatory ownership file lets `rbrain-deploy` discover services without hardcoded lists. Anything beyond this minimum starts to feel like central-planning overhead and gets ignored.

**Alternatives considered:**

- **Heavy template (cookiecutter with enforced folder layout)** — rejected: locks the polyglot stack into a uniform shape that doesn't fit any of the three languages well.
- **No conventions at all** — rejected: tooling and agents need at least a contract to navigate uniformly.

## Risks / Trade-offs

- **10 repos = 10 CI pipelines to maintain.** → Mitigation: `rbrain-deploy` centralizes shared CI templates and reusable workflows; new repos start from a template, not from scratch.
- **Polyglot stack (Rust + Python + TS) raises onboarding cost.** → Mitigation: each language is scoped to a single set of contexts; a contributor working on `forge` never has to know Python. The frontier between languages is the gateway, where HTTP normalizes everything.
- **Gateway is a single point of failure.** → Mitigation: gateway is stateless; horizontal scaling and standard load-balancing apply. Auth is short-circuited via JWT verification, so gateway downtime does not require re-auth.
- **DDD strict boundaries can lock the team into wrong cuts.** → Mitigation: this contract is revisable. A future change can split, merge, or rename contexts. The cost of moving a boundary is one OpenSpec change plus a repo rename — manageable while the system is small, and the right time to discover wrong cuts is precisely now.
- **No formal contract testing between contexts in v1.** → Mitigation: HTTP contracts will be specified per-context (OpenAPI); NATS event schemas will be specified per-channel. Contract testing tooling (Pact, schema registry) is deferred to a later change when there is enough traffic to justify it.

## Migration Plan

There is nothing to migrate — the platform does not exist yet. The execution path is:

1. Land this change (proposal + design + 3 specs + tasks) in `rbrain-codex`.
2. Scaffold the 9 sibling repositories against `repository-conventions`. This is a downstream task tracked in `tasks.md`.
3. Each sibling repo's first OpenSpec change anchors on these foundational specs.

No rollback is needed; if the contract proves wrong, a subsequent OpenSpec change amends it.

## Open Questions

- **Ownership metadata format**: YAML vs TOML, and which fields are mandatory (owner, on-call, runtime, dependencies?). Defer to `repository-conventions` spec.
- **AGENTS.md baseline content**: how much should be shared boilerplate vs. repo-specific. Defer to `repository-conventions` spec.
- **NATS subject naming convention**: `rbrain.<context>.<event>` vs. flatter scheme. Defer to `service-topology` spec.
- **Versioning of HTTP contracts**: URL path versioning (`/v1/...`) vs. header-based. Defer to a future `gateway-routing` spec.
