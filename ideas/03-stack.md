# MTG R.brain — Technology Stack

Core constraint: **resource frugality**. The full platform must run on modest infrastructure
(VPS, homelab) with a minimal memory footprint.

## Languages

| Layer | Language / Framework | Rationale |
|---|---|---|
| Data & infra services | **Rust / Axum + Tokio + SQLx** | 10–50 MB/service, static binary, zero JVM overhead |
| LLM orchestration | **Python 3.12 / FastAPI + LangGraph** | LLM ecosystem (LangGraph, instructor, Anthropic SDK) is Python-native and unmatched |
| Frontend | **Next.js 15 / TypeScript** | SSR, native WebSocket, mature ecosystem |

## Infrastructure

| Component | Choice | Dropped alternative | Reason |
|---|---|---|---|
| Database | **PostgreSQL + pgvector** | Elasticsearch | pgvector covers relational + vector search; avoids a JVM service (~1 GB) |
| Message bus | **NATS JetStream** | Kafka (KRaft) | Same semantics, ~40 MB vs ~512 MB |
| Cache | **Redis** | — | Standard; sessions + Scryfall cache |
| Gateway | **Rust / Axum** | Spring Cloud Gateway | Consistent with the rest of the backend stack |

## LLM abstraction

`rbrain-cortex` exposes a `LlmPort` interface with pluggable provider implementations:
- `ClaudeProvider` (Anthropic)
- `OllamaProvider` (self-hosted)
- `OpenAiProvider`

Active provider selected via config (`llm.provider: claude | ollama | openai`).

## Estimated memory footprint

| Component | RAM |
|---|---|
| 6 Rust services | ~160 MB total |
| rbrain-cortex (Python) | ~180 MB |
| PostgreSQL + pgvector | ~256 MB |
| Redis | ~50 MB |
| NATS JetStream | ~40 MB |
| rbrain-app (Node.js) | ~100 MB |
| **Total** | **~786 MB** |

Compared to a full Java/Spring Boot equivalent: ~4 GB. **~5× reduction.**

## Upgrade paths

- pgvector → **Qdrant** if vector search volume exceeds ~10M embeddings (port already isolated in `rbrain-oracle`)
- LangGraph → **pydantic-ai** if agent graph complexity stays low
