# rbrain-codex

The platform's spec and ADR repository for [MTG R.brain](https://github.com/mtg-r-brain) — an AI-powered reasoning platform built around Magic: The Gathering.

This repo is the **single source of truth** for who owns what across the ten `rbrain-*` repositories, how they talk to each other, and which conventions every repository must follow. No code-bearing repo can be conformant without consulting the files here.

## Entry points

| Question | Answer at |
|---|---|
| What bounded contexts exist, and what do they own? | [`openspec/specs/bounded-contexts/catalog.yaml`](openspec/specs/bounded-contexts/catalog.yaml) |
| Who calls whom over HTTP? | [`openspec/specs/service-topology/sync-graph.yaml`](openspec/specs/service-topology/sync-graph.yaml) |
| What does the NATS subject naming convention look like? | [`openspec/specs/service-topology/nats-naming.md`](openspec/specs/service-topology/nats-naming.md) |
| What must every `rbrain-*` repo ship? | [`openspec/specs/repository-conventions/templates/`](openspec/specs/repository-conventions/templates/) |
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
bash scripts/validate-catalog.sh    # 10 contexts, kebab-case, unique terms
bash scripts/validate-topology.sh   # known nodes, DAG via tsort
bash scripts/validate-repo.sh .     # this repo's own OWNERSHIP.yaml + mandatory files
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
