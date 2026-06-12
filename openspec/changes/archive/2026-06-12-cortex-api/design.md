## Context

The cortex BC ships a single public HTTP endpoint today: `POST /chat`. Its shape lives in `rbrain-cortex/app/chat/types.py` (Pydantic models `ChatRequest`, `ChatResponse`, `ToolCallTrace`) and is enforced by FastAPI at runtime; cortex's CI exercises the contract through `tests/test_chat_endpoint.py`. The internal behavior — ReAct loop, conversation store, tool registry composition — is normatively described by `cortex-bootstrap` in cortex's own `openspec/specs/`.

What's missing is the **external** contract: the slice gateway (today's internal callers, tomorrow's `rbrain-gateway` reverse-proxy) needs to commit to. Lexicon faced the same situation in May/June and was resolved by introducing the `lexicon-api` capability in codex, plus the `lexicon-api-admin-carveout` MODIFIED delta later. The lexicon-api experience is the strongest signal that cortex needs a symmetric capability.

Today's call graph (per `service-topology/sync-graph.yaml`):

- `gateway → cortex` (chat and agent invocations)
- `cortex → lexicon` (tool calls)
- `cortex → oracle` (tool calls, future)
- `cortex → forge` (tool calls, future)

There is no `app → cortex` direct edge: at the platform level the frontend goes through gateway, never direct. So the consumer of `cortex-api` is — and only is — `rbrain-gateway` once it ships. Until then, dev/test traffic hits cortex directly, but that's an operational shortcut, not a contract.

The `finish_reason` field surfaces the elephant. Today cortex hands back the LLM provider's raw `finish_reason` (anthropic: `end_turn` / `tool_use` / `max_tokens`; openai: `stop` / `tool_calls` / `length`; ollama: `stop`) plus its own `budget_exhausted` injection. That field is in the response and tested in `cortex-bootstrap`'s "Runaway agent loop terminates" scenario. Two options for the codex spec: ratify the leak as opaque, or force normalization. We pick the first (see Decision 2) — it lets cortex-api describe reality without forcing a code change, and leaves the door open for a future normalization change with its own design discussion.

## Goals / Non-Goals

**Goals:**

- Anchor the external HTTP contract for `rbrain-cortex` in codex, so future gateway/SDK work has a single source of truth.
- Lock the wire shape of request, response, and `tool_calls` trace entry — extra fields forbidden, types pinned.
- Establish a `finish_reason` discipline (reserved literal + opaque rest) that survives provider swaps and a future normalization slice.
- Close the public surface (POST /chat + GET /health only) so new public routes go through OpenSpec.
- Stay descriptive: zero code change in cortex.

**Non-Goals:**

- Streaming. `cortex-bootstrap` already states streaming is out of scope at v1; cortex-api echoes that without re-litigating.
- Per-provider `finish_reason` normalization. Worth doing eventually; out of scope here.
- WebSocket or SSE transport. Out of scope.
- Authentication. The public contract here is the wire shape; ingress auth lives with gateway and is a separate capability.
- Rate limiting, request size caps, idempotency keys. All future concerns, no current consumer, no spec drift cost.
- `/admin/*` carve-out. Cortex has no admin endpoints today. Adding the lexicon-api-admin-carveout pattern preemptively would be speculative — wait for a real admin endpoint to surface.
- Per-conversation listing endpoints (`GET /conversations/{id}`, etc.). The in-memory store has no persistence yet; cross-process listing is meaningless. Defer to `cortex-persistence` slice.

## Decisions

### Decision 1: One umbrella capability `cortex-api`, not multiple per-route capabilities

**Choice:** Single capability `cortex-api` carrying all public-surface requirements. Future routes (e.g., a `POST /completions` for a non-conversational path) accumulate via MODIFIED deltas, matching `lexicon-api`'s 7-requirement growth pattern.

**Rationale:** Mirrors the lexicon-api precedent that's already battle-tested (4 archived deltas including `lexicon-api-admin-carveout` and `card-search-api`). Keeping the per-BC API contract in one file makes "what does cortex's public surface look like?" a single Read away. Splitting per route would scatter the closure clause across files and force every "no other routes" requirement to enumerate the set, multiplying drift risk.

**Alternatives considered:**

- **Per-route capabilities (`cortex-chat-api`, future `cortex-completions-api`)**: rejected. Inflates the spec catalog without giving anything back; the closure clause has nowhere coherent to live.
- **No capability, document in cortex-bootstrap only**: rejected — that's exactly what lexicon-api was created to fix. The external contract belongs at the platform layer, not inside the BC's implementation spec.

### Decision 2: `finish_reason` is opaque + one reserved literal, not a normalized enum

**Choice:** The requirement on response shape spells out:

- `finish_reason` is `string | null`.
- The literal `"budget_exhausted"` is RESERVED to indicate the ReAct loop exited after MAX_ITERATIONS without producing text.
- Any other value is OPAQUE: it comes from the underlying LLM provider unchanged, and consumers SHALL NOT depend on its stability.

**Rationale:** Three reasons:

1. **Honest about today's behavior.** Cortex's code passes the provider's `finish_reason` straight through. Specifying an enum would force a code change (mapping layer + tests). That's a different ticket with its own trade-offs; conflating it with the cortex-api opening would slow this slice and pre-commit to a particular normalization.
2. **Preserves diagnostic value.** Operators triaging a malformed response benefit from knowing it was `tool_use` vs `length` vs `end_turn`. Stripping that detail (Decision 2 alternative 3) loses signal.
3. **Doesn't paint the door shut.** A future `cortex-finish-reason-normalization` MODIFIED change can introduce an enum on top of this requirement — the consumer-side opacity contract means today's clients can't have hardcoded `"end_turn"` checks that the normalization would break.

**Alternatives considered:**

- **Enum strict (`stop | tool_use | length | budget_exhausted | other`)**: rejected at the user-facing fork. Needs a mapping layer in `app/chat/router.py`, a unit test matrix per provider, and a maintenance cost when providers add new finish reasons. Worth doing eventually; not the right slice here.
- **Remove `finish_reason` from the response**: rejected at the user-facing fork. Removes a useful diagnostic and forces clients to inspect `response == BUDGET_EXHAUSTED_MESSAGE` to discriminate normal exits from budget exhaustion — string-comparison hell with i18n hazards.

### Decision 3: `tool_calls` carries a flat per-iteration trace, not a nested tree

**Choice:** `tool_calls` is a flat list of `{tool, args, observation}` triples in the order the agent invoked them. No grouping by iteration. No nested tool calls (cortex doesn't support tools that call other tools as a single unit today).

**Rationale:** Faithful to today's implementation (`ToolResult` in `app/tools/registry.py`, accumulated by `run_agent`). The agent's per-iteration grouping is recoverable from the assistant/tool message history if a future client really needs it — but today's three consumers (cortex's own tests, the smoke curl, future gateway) only need the flat trace. Don't pre-baroquify the contract.

**Alternatives considered:**

- **Grouped by ReAct iteration**: rejected. Imposes a structure cortex would have to manufacture; no current consumer asks for it.
- **Omit `tool_calls` and emit them as `Server-Sent Events`**: rejected — that's the streaming non-goal.

### Decision 4: Reuse `repository-conventions` for `GET /health` instead of restating it in cortex-api

**Choice:** Requirement 5 ("No other public HTTP routes at v1") references `repository-conventions` for the `/health` requirement instead of inlining it. The lexicon-api scenario does the same.

**Rationale:** Single source of truth. If `/health` ever evolves (e.g., readiness vs liveness split), `repository-conventions` is the one place to change. Cortex-api stays focused on cortex-specific routes.

### Decision 5: Match `lexicon-api`'s `extra fields forbidden` clause and rationale

**Choice:** Each shape requirement (request, response, trace entry) states explicitly that no field outside the named set may appear, and that adding a field requires a MODIFIED delta on this spec.

**Rationale:** Matches lexicon-api's "Extra fields are forbidden" scenarios. The Pydantic models already do this with `model_config = ConfigDict(extra="forbid")`; the spec ratifies the choice so it can't drift in a future code change without a corresponding codex change.

## Risks / Trade-offs

- **[Risk] Ratifying provider passthrough as `finish_reason` discipline locks the door on normalization** → Mitigation: not really — the opacity clause means existing consumers can't depend on the raw values, so a normalization layer can be introduced later without a breaking change. The trade-off is honest documentation of today's behavior vs. nudging cortex toward normalization sooner. We pick honest documentation.

- **[Risk] Cortex grows a route that's hard to classify (e.g., websocket upgrade for streaming) and the closure clause becomes the brake** → Accepted. That's exactly the point of the closure clause: any expansion gets a codex review. The lexicon-api carve-out precedent (admin/*) shows the mechanism handles real exceptions cleanly.

- **[Trade-off] We could pre-emptively add an `/admin/*` carve-out the way lexicon-api eventually needed one** → Rejected. Speculative carve-outs grow the spec without delivering. The carve-out can be added the day cortex needs its first admin endpoint, exactly as lexicon did.

- **[Risk] A future `rbrain-app` adds direct frontend access to cortex** → That would be a service-topology change, NOT a cortex-api change. Cortex-api describes the wire shape, not who calls it. The caller invariant lives in `service-topology/sync-graph.yaml`. Cross-spec hygiene preserved.

- **[Trade-off] `tool_calls` carries the raw args the LLM produced** → Accepted. The LLM's args are the right input for downstream traces, replay, and debugging. Sanitizing them would hide real model behavior, which is the opposite of useful for ops.

## Open Questions

None. The five-requirement scope is bounded by today's cortex implementation; every decision has a clear owner (cortex code as source of truth, codex spec as ratification).
