# rbrain-codex

The platform's spec and ADR repository for [MTG R.brain](https://github.com/mtg-r-brain) — an AI-powered reasoning platform built around Magic: The Gathering.

This repo is the **single source of truth** for who owns what across the ten `rbrain-*` repositories, how they talk to each other, and which conventions every repository must follow. No code-bearing repo can be conformant without consulting the files here.

## Entry points

| Question | Answer at |
|---|---|
| What bounded contexts exist, and what do they own? | [`openspec/specs/bounded-contexts/catalog.yaml`](openspec/specs/bounded-contexts/catalog.yaml) |
| Who calls whom over HTTP? | [`openspec/specs/service-topology/sync-graph.yaml`](openspec/specs/service-topology/sync-graph.yaml) |
| What does the NATS subject naming convention look like? | [`openspec/specs/service-topology/nats-naming.md`](openspec/specs/service-topology/nats-naming.md) |
| Which runtime does each context use? | [`openspec/specs/language-runtimes/runtime-allocation.yaml`](openspec/specs/language-runtimes/runtime-allocation.yaml) |
| What memory budget per context, what platform ceiling? | [`openspec/specs/language-runtimes/memory-budgets.yaml`](openspec/specs/language-runtimes/memory-budgets.yaml) |
| Which LLM providers are supported, which env vars do they read? | [`openspec/specs/llm-abstraction/providers.yaml`](openspec/specs/llm-abstraction/providers.yaml) |
| Which PostgreSQL roles own which schema? | [`openspec/specs/data-stores/postgres-roles.yaml`](openspec/specs/data-stores/postgres-roles.yaml) |
| What must every `rbrain-*` repo ship? | [`openspec/specs/repository-conventions/templates/`](openspec/specs/repository-conventions/templates/) |
| What HTTP contract does each sibling expose? | [`openspec/specs/<context>-api/spec.md`](openspec/specs/) (e.g. `lexicon-api`) |
| What's currently being planned? | [`openspec/changes/`](openspec/changes/) |

## Workflow

This repo uses [OpenSpec](https://github.com/Fission-AI/OpenSpec) — every change to platform contracts goes through a four-artifact workflow:

```
proposal.md → specs/<capability>/spec.md → design.md → tasks.md
```

Each change lives under `openspec/changes/<change-name>/` until it's implemented and archived (promoted to `openspec/specs/`).

The OpenSpec CLI shortcuts in use:

| Command | Effect |
|---|---|
| `openspec new change <name>` | Scaffold a new change directory |
| `openspec status --change <name>` | Show progress per artifact |
| `openspec instructions <artifact> --change <name>` | Print template + guidance for the next artifact |
| `openspec archive <name>` | Promote a completed change's specs into `openspec/specs/` |

## Validators

CI runs the validators on every push to `main` and on every pull request. Run them locally before pushing:

```sh
bash scripts/validate-catalog.sh        # 10 contexts, kebab-case, unique terms
bash scripts/validate-topology.sh       # known nodes, DAG via tsort
bash scripts/validate-runtimes.sh       # runtime allocation + memory budgets vs. ceiling
bash scripts/validate-data-stores.sh    # 5 PG roles, schema-per-context, no cross-schema grants
bash scripts/validate-subjects.sh       # NATS subject naming on every OWNERSHIP.yaml
bash scripts/validate-llm-config.sh     # 3 LLM providers, env var coverage
bash scripts/validate-repo.sh .         # this repo's own OWNERSHIP.yaml + mandatory files
```

## Scaffolding sibling repositories

`scripts/scaffold-repo.sh` materializes a new `rbrain-*` sibling from a runtime-scoped template. Every value is resolved from the YAML sources above — no flags carry business data:

```sh
bash scripts/scaffold-repo.sh <context-name> [<target-dir>] [--force]
```

By default the output lands at `../rbrain-<context-name>/`. The script runs `validate-repo.sh` against its output and points at [`openspec/specs/scaffold-procedure/checklist.md`](openspec/specs/scaffold-procedure/checklist.md) for the post-scaffold steps (create the GitHub repo, push, enable CI, etc.).

Three templates live under [`openspec/specs/scaffold-templates/templates/`](openspec/specs/scaffold-templates/templates/), indexed by runtime: `rust-service/`, `python-service/`, `typescript-app/`. Contexts whose runtime is `none` (`codex`, `deploy`) are bespoke and not served by the scaffolder.

A CI job (`scaffold-drift`) compares the dry-run output against [checked-in baselines](openspec/specs/scaffold-procedure/baselines/) for the eight scaffoldable contexts. When you edit a template or a YAML source, refresh the baselines in the same commit:

```sh
bash scripts/refresh-baselines.sh
```

The validators require [`yq`](https://github.com/mikefarah/yq) (Go-based, v4+). Install via `brew install yq` on macOS.

`validate-repo.sh` is fetched by every sibling `rbrain-*` repo's CI from this repo's `main` branch — see `openspec/specs/scaffold-templates/spec.md` (under change `scaffold-sibling-repos`) for the exact mechanism.

## Sibling repositories

| Repo | Runtime | Responsibility |
|---|---|---|
| `rbrain-gateway` | rust | HTTP ingress, auth middleware, rate limit |
| `rbrain-identity` | rust | Accounts, sessions, JWT, OAuth2 |
| `rbrain-lexicon` | rust | Card catalogue + Scryfall sync |
| `rbrain-oracle` | rust | Rules engine + RAG |
| `rbrain-forge` | rust | Deck parsing, storage, analysis |
| `rbrain-chronicle` | rust | Editorial blog |
| `rbrain-cortex` | python | LLM orchestration, agent tool-calling |
| `rbrain-app` | typescript | Next.js frontend |
| `rbrain-deploy` | none | docker-compose + Helm |
| `rbrain-codex` | none | This repo — specs and ADRs |

## License

TBD.
