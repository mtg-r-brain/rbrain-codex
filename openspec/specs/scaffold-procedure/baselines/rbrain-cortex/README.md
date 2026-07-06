# rbrain-cortex

Orchestrates LLM agents, conversations, and tool invocations across lexicon, oracle, and forge.

Part of the [MTG R.brain](https://github.com/mtg-r-brain) platform. The contract this repo honors lives in [`rbrain-codex`](https://github.com/mtg-r-brain/rbrain-codex). See `AGENTS.md` for the bootstrap.

## Stack

- **Runtime**: python (>= 3.12)
- **Memory budget**: 176 MB
- **Framework**: FastAPI >= 0.115 + Uvicorn
- **Package manager**: [`uv`](https://github.com/astral-sh/uv)

## Local development

```sh
uv sync                              # installs deps + dev tools
uv run uvicorn app.main:app --host 0.0.0.0 --port 8080
curl http://localhost:8080/health    # {"status":"ok","context":"cortex"}
```

## Quality gates

```sh
uv run ruff check .
uv run ruff format --check .
uv run mypy app
uv run pytest
bash <(curl -fsSL https://raw.githubusercontent.com/mtg-r-brain/rbrain-codex/main/scripts/validate-repo.sh) .
```

CI runs all of the above on every push and PR.

## Contract

This repo MUST honor the rbrain-codex specs — see `AGENTS.md` for the list.
