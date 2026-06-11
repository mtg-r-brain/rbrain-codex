# rbrain-oracle

Answers Magic: The Gathering rules questions by retrieving and reasoning over the comprehensive rules and community sources.

Part of the [MTG R.brain](https://github.com/mtg-r-brain) platform. The contract this repo honors lives in [`rbrain-codex`](https://github.com/mtg-r-brain/rbrain-codex). See `AGENTS.md` for the bootstrap.

## Stack

- **Runtime**: rust (>= 1.83)
- **Memory budget**: 40 MB
- **Framework**: Axum 0.7 + Tokio 1.40
- **Persistence**: see `openspec/specs/data-stores/spec.md` in `rbrain-codex`

## Local development

```sh
cargo build --locked
cargo run                            # listens on 0.0.0.0:8080
curl http://localhost:8080/health    # {"status":"ok","context":"oracle"}
```

## Quality gates

```sh
cargo clippy --all-targets -- -D warnings
cargo fmt --check
bash <(curl -fsSL https://raw.githubusercontent.com/mtg-r-brain/rbrain-codex/main/scripts/validate-repo.sh) .
```

CI runs all of the above on every push and PR.

## Contract

This repo MUST honor:

- [`openspec/specs/repository-conventions/spec.md`](https://github.com/mtg-r-brain/rbrain-codex/blob/main/openspec/specs/repository-conventions/spec.md) — mandatory files + OWNERSHIP.yaml schema
- [`openspec/specs/language-runtimes/spec.md`](https://github.com/mtg-r-brain/rbrain-codex/blob/main/openspec/specs/language-runtimes/spec.md) — runtime allocation + version floor + memory budget
- [`openspec/specs/service-topology/spec.md`](https://github.com/mtg-r-brain/rbrain-codex/blob/main/openspec/specs/service-topology/spec.md) — who calls who, NATS subject naming

Any drift is caught by `validate-repo.sh` fetched at CI run time from `rbrain-codex` `main`.
