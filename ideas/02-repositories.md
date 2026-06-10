# MTG R.brain — Repository Collection

10 independent repositories, one per DDD bounded context.
Each repo is autonomously deployable with its own CI/CD pipeline.

## Repositories

| Repository | Role |
|---|---|
| `rbrain-codex` | ADRs, OpenSpec proposals, living specs — this repo |
| `rbrain-gateway` | Routing, auth middleware, rate limiting |
| `rbrain-identity` | User accounts, JWT, OAuth2 (Google, Discord) |
| `rbrain-lexicon` | Card catalogue, Scryfall sync, full-text search |
| `rbrain-oracle` | Rules engine, semantic search, RAG pipeline |
| `rbrain-forge` | Deck management, upload parsing, format validation |
| `rbrain-cortex` | LLM agent orchestration, tool-calling, conversations |
| `rbrain-chronicle` | Editorial blog, content management |
| `rbrain-app` | Next.js frontend — chat UI, deck builder, blog |
| `rbrain-deploy` | docker-compose (local) + Helm chart (production) |

## Dependency graph

```
rbrain-app
  └─→ rbrain-gateway
        ├─→ rbrain-identity    [auth]
        ├─→ rbrain-cortex      [chat / agents]
        │     ├── tool: rbrain-lexicon   (card search)
        │     ├── tool: rbrain-oracle    (rules + RAG)
        │     └── tool: rbrain-forge     (deck analysis)
        └─→ rbrain-chronicle   [blog]
```

## Naming rationale

- **lexicon**: the authoritative vocabulary of cards — neutral, no competitor overlap
- **oracle**: MTG's own term for the official card text ruling — legitimate, project-native
- **forge**: MTG-adjacent term for building/crafting decks — generic enough
- **cortex**: the reasoning layer of R.brain — project-specific, no competitor overlap
- **chronicle**: generic editorial term, distinct from competitor naming
