# lexicon — Agent Bootstrap

Conformant to the AGENTS.md baseline defined in `openspec/specs/repository-conventions/spec.md` in `rbrain-codex`.

## Responsibility

Maintains the authoritative card catalogue synced from Scryfall and serves full-text card search.

## Non-responsibilities

- rules text interpretation
- deck legality enforcement
- card pricing or market data

## Owned vocabulary

- card
- set
- printing
- scryfall-id
- oracle-id
- mana-cost
- color-identity

## Synchronous callers

- cortex

## Synchronous callees

(none)

## Published events (NATS)

(none)

## Runtime

This repo runs on `rust` `>= 1.83.0` with a memory budget of `30` MB. CI enforces both via `validate-repo.sh` fetched from `rbrain-codex` `main`.

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

Every PR that ships behavioral change SHOULD run a representative load and verify RSS stays under `30` MB. Exceeding the budget is a contract violation; either optimize the service or file an OpenSpec change against `language-runtimes`.

### Conventions

- English everywhere (commits, PRs, docs, code comments) — global rbrain rule.
- Gitmoji commits.
- Tracing in JSON; no `println!` in production paths.
- All public types/functions documented; clippy `-D warnings` enforces this.
