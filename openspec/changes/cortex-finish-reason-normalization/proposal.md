## Why

`cortex-api` was archived earlier today (2026-06-12) with `finish_reason` defined as `string | null` carrying either the reserved literal `"budget_exhausted"` or an opaque provider passthrough. The opacity was a deliberate decision: it described reality without forcing a code change, and the design.md explicitly flagged "a future `cortex-finish-reason-normalization` MODIFIED change can introduce an enum on top of this requirement".

That future is now. Reasons to pay the debt immediately rather than wait for a client:

1. **The closure clause is empty.** No client today depends on opaque provider values, so a normalisation cannot break anyone. Every week we wait is a week a client could ship a `finish_reason === "end_turn"` check we'd then be stuck supporting.
2. **`rbrain-gateway` is the next likely consumer.** When gateway proxies `POST /chat`, it should be able to switch on `finish_reason` (e.g., for telemetry buckets, retry policy) without knowing which LLM provider cortex is configured with. A closed enum is the right primitive for that.
3. **The mapping is small and uncontroversial.** Anthropic / OpenAI / Ollama all surface a handful of stop conditions that compress into 4 canonical buckets plus a fallback. Cortex's own `budget_exhausted` is already a 5th. Designing the enum is a one-shot exercise; the table doesn't grow with provider count.

## What Changes

- MODIFY the `cortex-api` requirement **"POST /chat response body shape"** so `finish_reason` becomes a closed enum of exactly five values: `"stop"`, `"tool_use"`, `"length"`, `"budget_exhausted"`, `"other"`. `null` remains permitted (provider produced no finish reason at all).
- ADD a normative mapping table in the same requirement covering every documented `finish_reason` value across the three providers in `llm-abstraction` (anthropic, openai, ollama) plus the cortex-injected `"budget_exhausted"`.
- ADD a new `cortex-api` requirement **"finish_reason normalisation is provider-agnostic"** explaining that cortex SHALL apply the mapping before serialising the response — the opaque passthrough described by the v1 requirement no longer holds.
- Implementation in `rbrain-cortex` (no separate codex change, follows the `ollama-cloud-auth` pattern):
  - ADD `app/chat/finish_reason.py` with a pure `normalize(value: str | None) -> str | None` function implementing the mapping table.
  - WIRE the call in `app/chat/router.py` so the response's `finish_reason` is always the normalised value.
  - ADD `tests/test_finish_reason.py` covering the mapping table per provider value, the cortex-injected literal, the `null` passthrough, and the `other` fallback.
  - UPDATE `tests/test_chat_endpoint.py` if it asserts on `finish_reason` raw values.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `cortex-api`: MODIFIED requirement "POST /chat response body shape" (finish_reason becomes a closed enum + mapping table); ADDED requirement "finish_reason normalisation is provider-agnostic" (the normalisation rule itself, scenario-driven).

## Impact

- **Code**: `rbrain-cortex/app/chat/finish_reason.py` (new), `rbrain-cortex/app/chat/router.py` (one-line wire-up), `rbrain-cortex/tests/test_finish_reason.py` (new), possibly `rbrain-cortex/tests/test_chat_endpoint.py` (assertion tweaks if any).
- **APIs**: BREAKING for any client depending on raw provider `finish_reason` values. Per the v1 cortex-api opacity clause, no compliant client should exist — but if one did, it would now see `"stop"` instead of `"end_turn"`. Acceptable because:
  - The v1 spec explicitly forbade depending on opaque values.
  - No cortex consumer is in production today (rbrain-gateway is scaffold-only).
- **Dependencies**: none. Standard-library `enum`-free implementation (string constants) keeps the change small.
- **Specs touched**: codex only (MODIFIED on `cortex-api`). `cortex-bootstrap` does NOT need a delta — its existing "Runaway agent loop terminates" scenario already specifies `"budget_exhausted"` as the cortex-injected literal, which the normalisation preserves as-is.
- **Validators**: unaffected.
- **Migration**: none beyond the cortex code change shipped in the same change.
