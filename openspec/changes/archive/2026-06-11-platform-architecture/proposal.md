## Why

MTG R.brain is starting with 10 bounded contexts identified in `ideas/02-repositories.md` but with no formal contract on their boundaries, their communication patterns, or the conventions every `rbrain-*` repository must follow. Without this foundation, every downstream capability spec (rules agent, deck agent, card catalogue, etc.) will re-litigate where to draw the line — and inconsistent repos will diverge in structure and tooling. Locking the platform contract first prevents that drift.

## What Changes

- Formalize the 10 bounded contexts (`gateway`, `identity`, `lexicon`, `oracle`, `forge`, `cortex`, `chronicle`, `app`, `deploy`, `codex`) as first-class architectural units, each with an explicit responsibility, owned domain language, and explicit non-responsibilities.
- Establish the dependency graph between contexts as a contract: who may call whom, in which direction, and through which transport (synchronous HTTP vs. asynchronous NATS event).
- Define repository-level conventions every `rbrain-*` repo must honor: naming, top-level structure, mandatory files (README, AGENTS.md, CI manifest), ownership metadata.
- Declare the communication boundaries: the gateway is the single ingress for the frontend; cross-context calls between backend services are explicit and listed; no hidden coupling.

This change introduces no breaking changes — there is nothing to break yet.

## Capabilities

### New Capabilities

- `bounded-contexts`: Definition of each DDD context, its responsibility, its owned vocabulary, and its non-responsibilities. The authoritative answer to "which repo owns X".
- `service-topology`: The dependency graph between contexts, allowed call directions, transport per edge (HTTP/REST, NATS event), and the gateway-as-single-ingress rule.
- `repository-conventions`: Mandatory structure, files, and metadata every `rbrain-*` repository must provide so tooling (CI, agents, deploy) can treat them uniformly.

### Modified Capabilities

None — no prior specs exist.

## Impact

- **Future specs**: every subsequent capability spec (rules-agent, deck-agent, card-catalogue, conversational-chat, deck-upload, user-accounts, editorial-blog, llm-abstraction, deployment-topology, gateway-routing) will anchor on these three foundational specs and cite them as prerequisites.
- **Repository scaffolding**: the 9 sibling repositories (`rbrain-gateway`, `rbrain-identity`, `rbrain-lexicon`, `rbrain-oracle`, `rbrain-forge`, `rbrain-cortex`, `rbrain-chronicle`, `rbrain-app`, `rbrain-deploy`) will be created against this contract; their initial scaffolding becomes a downstream task.
- **No code change in this repo yet**: `rbrain-codex` holds specs and ADRs only; this change produces documentation that other repos must comply with.
- **Out of scope**: implementation choices that belong to the `technology-stack` spec (Rust/Python/Next.js selection, database, message bus). Stack is referenced where it determines a topology edge but not justified here.
