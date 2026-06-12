## 1. Codex spec authorship

- [x] 1.1 Draft MODIFIED requirement "POST /chat response body shape": replace the opaque-passthrough clause with the closed enum table (5 values + null); update scenarios to assert canonical values
- [x] 1.2 Draft ADDED requirement "finish_reason normalisation is provider-agnostic" with the mapping table and 5 scenarios (each provider mapping bucket, budget_exhausted preservation, unknown-value fallback, null preservation)
- [x] 1.3 `openspec validate cortex-finish-reason-normalization --strict` clean

## 2. Codex CI

- [x] 2.1 Push the 4 planning commits in rbrain-codex; verify codex CI workflow goes green (7 validators + scaffold-drift)

## 3. Cortex implementation

- [x] 3.1 Add `rbrain-cortex/app/chat/finish_reason.py` exposing `CANONICAL_VALUES: tuple[str, ...]` (the 5 string literals) and `normalize(value: str | None) -> str | None` implementing the codex mapping table; unknown values log via `structlog` at WARN and return `"other"`; `None` returns `None`
- [x] 3.2 Wire the call in `rbrain-cortex/app/chat/router.py` so `ChatResponse.finish_reason` is `normalize(agent_result.finish_reason)`; keep `AgentResult.finish_reason` carrying the raw value for internal diagnostics
- [x] 3.3 Add `rbrain-cortex/tests/test_finish_reason.py` with: parametrised test covering every row in the mapping table (one assertion per raw value → canonical); test for `None` passthrough; test that unknown value returns `"other"` and triggers exactly one log entry (caplog); test that `CANONICAL_VALUES` matches the spec table
- [x] 3.4 Update `rbrain-cortex/tests/test_chat_endpoint.py` if it asserts on `finish_reason` raw values (likely it doesn't — the tests use a mock LLM that returns `"stop"` or no value)
- [x] 3.5 `uv run ruff check . && uv run ruff format --check . && uv run mypy app && uv run pytest -x` all green

## 4. Cortex CI

- [x] 4.1 Push the 2 apply commits to rbrain-cortex (feat + docs/tests, see [[interactive-and-atomic-commits]])
- [x] 4.2 Verify cortex CI workflow goes green

## 5. Archive and handoff

- [x] 5.1 Run `/opsx:archive cortex-finish-reason-normalization` in codex to promote the MODIFIED + ADDED delta into `openspec/specs/cortex-api/spec.md`
- [x] 5.2 Push the archive commit; verify codex CI stays green
- [x] 5.3 Update the platform handoff drawer in MemPalace marking the finish_reason debt closed
