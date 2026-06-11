# ${CONTEXT_NAME} — Agent Bootstrap

Conformant to the AGENTS.md baseline defined in `openspec/specs/repository-conventions/spec.md` in `rbrain-codex`.

## Responsibility

${RESPONSIBILITY}

## Non-responsibilities

${NON_RESPONSIBILITIES}

## Owned vocabulary

${OWNED_TERMS}

## Synchronous callers

${CALLERS}

## Synchronous callees

${CALLEES}

## Published events (NATS)

${PUBLISHES}

## Runtime

This repo runs on `${RUNTIME}` `>= 3.12` with a memory budget of `${MAX_RSS_MB}` MB. CI enforces both via `validate-repo.sh` fetched from `rbrain-codex` `main`.

## Working in this repo

### Stack

- Python 3.12 (PEP 695 type aliases, `tomllib`)
- FastAPI >= 0.115 + Uvicorn with `[standard]` extras (websockets, http-tools)
- LangGraph >= 0.2 for the agent orchestration in `cortex`; not pulled in by the scaffold
- `structlog` for JSON logging; `ruff` + `mypy --strict` for quality
- `uv` for dependency management — never use bare `pip` in this repo

### Build, test, run

```sh
uv sync
uv run uvicorn app.main:app --host 0.0.0.0 --port 8080
uv run ruff check .
uv run ruff format --check .
uv run mypy app
uv run pytest
```

### Memory ceiling

Every PR that ships behavioral change SHOULD verify RSS stays under `${MAX_RSS_MB}` MB under representative load. The ceiling is enforced by `validate-repo.sh` (declared value vs. budgets.yaml); deviations need an OpenSpec change against `language-runtimes`.

### Conventions

- English everywhere (commits, PRs, docs, code comments).
- Gitmoji commits.
- `ruff` and `mypy --strict` enforced — no `# type: ignore` without an inline reason.
- JSON logs via `structlog`; no `print()` in production paths.
