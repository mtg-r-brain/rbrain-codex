# gateway — Agent Bootstrap

Conformant to the AGENTS.md baseline defined in `openspec/specs/repository-conventions/spec.md` in `rbrain-codex`.

## Responsibility

Routes external HTTP traffic to backend contexts, enforces authentication, and applies rate limiting.

## Non-responsibilities

- LLM orchestration
- business logic of any backend context
- card catalogue queries (delegated to cortex which calls lexicon)

## Owned vocabulary

- ingress
- http-route
- rate-limit
- middleware

## Synchronous callers

- app

## Synchronous callees

- identity
- cortex
- chronicle
- forge

## Published events (NATS)

(none)

## Runtime

This repo runs on `rust` `>= 1.83.0` with a memory budget of `35` MB. CI enforces both via `validate-repo.sh` fetched from `rbrain-codex` `main`.

## Working in this repo

### Stack

- Axum 0.7 + Tokio 1.40 (rt-multi-thread + macros + signal)
- Tower 0.5 + tower-http 0.6 for middleware
- SQLx for persistence (when needed; not included in the scaffold)
- `tracing` + `tracing-subscriber` with JSON output

### Build, test, run

```sh
cargo build --locked
cargo run
cargo clippy --all-targets -- -D warnings
cargo fmt --check
```

### Memory ceiling

Every PR that ships behavioral change SHOULD run a representative load and verify RSS stays under `35` MB. Exceeding the budget is a contract violation; either optimize the service or file an OpenSpec change against `language-runtimes`.

### Conventions

- English everywhere (commits, PRs, docs, code comments) — global rbrain rule.
- Gitmoji commits.
- Tracing in JSON; no `println!` in production paths.
- All public types/functions documented; clippy `-D warnings` enforces this.
