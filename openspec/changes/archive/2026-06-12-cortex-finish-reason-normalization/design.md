## Context

`cortex-api` v1 ratified `finish_reason` as `string | null` with `"budget_exhausted"` reserved and every other value opaque-from-provider. The design.md openly said: "A future `cortex-finish-reason-normalization` MODIFIED change can introduce an enum on top of this requirement — the consumer-side opacity contract means today's clients can't have hardcoded `'end_turn'` checks that the normalization would break."

This change is that follow-up, executed the same day. Justified because:

- No client is in production (rbrain-gateway is scaffold-only; rbrain-app does not exist as a real client yet). The opacity clause is technically intact but practically empty.
- Cortex's three providers (anthropic, openai, ollama) surface a small, well-documented set of finish reasons. The mapping is easy to enumerate exhaustively.
- Doing it now consolidates: one less "open dette" in the spec catalogue, one less surprise when the gateway slice arrives.

Provider documented values (cross-checked against vendor SDKs as of 2026-06-12):

| Provider  | Documented `finish_reason` values                                                                 |
|-----------|---------------------------------------------------------------------------------------------------|
| anthropic | `end_turn`, `tool_use`, `max_tokens`, `stop_sequence`, `pause_turn`, `refusal`                    |
| openai    | `stop`, `length`, `tool_calls`, `content_filter`, `function_call` (deprecated)                    |
| ollama    | `stop`, `length`, `tool_calls` (OpenAI-compatible)                                                 |

`pause_turn` (anthropic) is a recent addition for long-running thinking; in cortex's bounded ReAct loop it should not surface because we don't enable extended thinking. We map it to `other` defensively.

`function_call` (openai deprecated) maps to `tool_use` — same intent.

## Goals / Non-Goals

**Goals:**

- Define a closed enum of canonical finish_reason values plus `null`.
- Specify the mapping from every documented provider value to the canonical enum.
- Preserve the cortex-injected `"budget_exhausted"` literal end-to-end.
- Implement the mapping in cortex as a pure function with exhaustive tests.
- Keep the change small: one cortex code module, no new dependencies.

**Non-Goals:**

- Mapping based on `(provider_name, value)` tuples. The union is collision-free; the normaliser stays a pure `str | None -> str | None` function.
- Surfacing a separate `provider_finish_reason` field in the response for clients that want the raw value. If demand surfaces, add via a separate MODIFIED later. Pre-emptive multiplexing inflates the contract for zero current consumers.
- Mapping into a Python `enum.Enum` exposed across module boundaries. String constants are simpler, JSON-friendly, and just as type-safe with `Literal`.
- Provider-specific telemetry on which value was normalised away. The normaliser logs once at WARN when it falls through to `other`; that's sufficient for ops to find new provider values.

## Decisions

### Decision 1: Closed enum of 5 values, no `refusal` bucket

**Choice:** Canonical set is exactly `{"stop", "tool_use", "length", "budget_exhausted", "other"}`. Refusals/content-filters map to `"other"`.

**Rationale:** Two reasons:

1. **Refusal handling is a separate concern.** A client that wants to react to refusals should look at the `response` text content (which is what the model actually said) plus structured safety signals from the provider, not finish_reason. Pretending finish_reason is the discrimination channel encourages bad client design.
2. **Adding a bucket later is non-breaking.** Going from 5 to 6 buckets via MODIFIED moves values from `"other"` to a more specific bucket; clients that hardcoded `"other"` checks break, but that's already an anti-pattern (the spec describes `"other"` as a fallback, not a stable signal).

**Alternatives considered:**

- **6 values with `refusal` as its own bucket**: rejected. Speculative — no current consumer needs the distinction.
- **3 values (`stop`, `length`, `other`)**: rejected. Conflates "model wants to call a tool" with "model stopped naturally"; gateway-style routers will want that distinction for telemetry.
- **String `null`-only contract (drop finish_reason)**: rejected — we already considered this in cortex-api design and chose to keep the diagnostic field.

### Decision 2: `null` is preserved end-to-end

**Choice:** If the provider returns `null` (no finish reason at all — e.g., streaming-aborted from a non-streaming SDK call, or a malformed provider response), the normaliser returns `null`. It does NOT default to `"other"`.

**Rationale:** `null` carries information: "we don't know why this stopped". Conflating with `"other"` ("we know it stopped, the reason isn't in our enum") loses signal for diagnostics. Cortex's own `"budget_exhausted"` is the explicit signal for "loop exited without provider involvement", so there's no need to collapse `null` into a sentinel.

### Decision 3: Normalisation lives in a tiny pure module, not inside the agent loop

**Choice:** `app/chat/finish_reason.py` exposes one function: `normalize(value: str | None) -> str | None`. The router calls it once when building `ChatResponse`. The agent loop continues to carry the raw value in `AgentResult.finish_reason`; normalisation happens at the boundary between cortex's internal types and the wire response.

**Rationale:** Three benefits:

1. **Testability.** A pure function is the cheapest possible thing to unit-test exhaustively (one test per provider value).
2. **Provider transparency at debug time.** Logs and traces inside cortex carry the raw `end_turn` / `tool_use` / etc., which is what a developer wants when investigating a provider's behaviour. Only the external response is canonical.
3. **Easy to extend.** New provider values land in one file; no agent-loop changes needed.

**Alternatives considered:**

- **Normalise inside `run_agent`**: rejected. Mixes concerns (loop control + wire shaping); loses the raw value for internal diagnostics.
- **Normalise in each provider adapter (`anthropic.py`, `openai.py`, `ollama.py`)**: rejected. Spreads the mapping across three files; the union table becomes invisible.

### Decision 4: Unknown provider values fall through to `"other"` with a single WARN log

**Choice:** If `normalize` receives a value not in its known mapping, it returns `"other"` and emits one `logger.warning("unknown finish_reason", value=value)`. No exception, no metrics counter.

**Rationale:** Provider SDKs add new values occasionally (anthropic's `pause_turn` is a recent example). Crashing on the unknown would make every cortex deploy a hostage to provider release notes. Silent passthrough would hide the new value from ops. A WARN log is the right middle ground: ops sees the value in logs, files a follow-up to extend the enum, life continues. The metrics counter would be over-engineering for a once-per-provider-release event.

## Risks / Trade-offs

- **[Risk] A provider introduces a value we should explicitly bucket but we miss it** → Mitigation: the WARN log surfaces it. The friction here is small (a follow-up MODIFIED takes ~30 min) and acceptable.

- **[Trade-off] We lose the raw provider finish_reason at the wire** → Accepted. Clients that need the raw value are diagnostic consumers, and diagnostic consumers should look at structured logs, not response bodies.

- **[Risk] `"other"` becomes a catch-all that hides important distinctions** → Mitigation: monitor logs for `unknown finish_reason` warnings during the first weeks; extend the enum if a new bucket is justified by recurring values. The opacity contract on `"other"` allows extension without breakage.

- **[Risk] OpenAI deprecates `function_call` and removes it entirely** → No mitigation needed — our mapping already covers it; if OpenAI removes it from responses, we just stop seeing that value, which is fine.

- **[Trade-off] No `provider_finish_reason` raw passthrough field** → Accepted. Pre-emptive multiplexing for zero consumers. Add when a consumer asks.

## Open Questions

None. The mapping table is closed by today's provider documentation; new arrivals get handled by the `"other"` + WARN flow.
