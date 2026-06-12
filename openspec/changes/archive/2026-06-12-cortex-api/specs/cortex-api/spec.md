## ADDED Requirements

### Requirement: rbrain-cortex exposes POST /chat

`rbrain-cortex` SHALL expose an HTTP endpoint at the path `POST /chat` on its declared service port. The endpoint takes a JSON request body and returns a JSON response body. Streaming responses are NOT supported at v1.

Callers reachable by this endpoint follow the synchronous call graph in `service-topology/sync-graph.yaml`. At v1, the only declared in-cluster caller is `rbrain-gateway` via the `gateway → cortex` edge. Direct ingress from `rbrain-app` is NOT a supported caller.

#### Scenario: gateway calls POST /chat

- **WHEN** `rbrain-gateway` issues `POST /chat` against `rbrain-cortex` with a valid request body
- **THEN** the request SHALL reach the cortex chat handler and produce either the 200 response defined below or a 4xx validation response; the call SHALL NOT involve `rbrain-app` directly in the synchronous path

#### Scenario: handler runs synchronously

- **WHEN** the agent loop runs a multi-iteration ReAct cycle before returning text
- **THEN** the HTTP response SHALL be produced after the loop terminates; no chunked transfer, no Server-Sent Events, no WebSocket upgrade SHALL be used at v1

### Requirement: POST /chat request body shape

The request body SHALL be a JSON object with exactly the two fields below, in any key order:

| Field             | Type             | Required | Description                                                                                          |
|-------------------|------------------|----------|------------------------------------------------------------------------------------------------------|
| `message`         | string           | yes      | The user's message for this conversation turn. Length SHALL be at least one character.               |
| `conversation_id` | string \| null   | no       | Existing conversation id to continue. Absent or `null` → server allocates a fresh UUID4.             |

No other fields SHALL appear in the request body. Adding a request-side field (e.g., `system_prompt_override`, `tools_filter`, `model_override`) requires a MODIFIED delta on this requirement.

#### Scenario: minimal valid request

- **WHEN** a caller sends `{"message": "Hello"}` with no `conversation_id`
- **THEN** the server SHALL treat the request as starting a new conversation; the response SHALL carry a freshly allocated UUID in `conversation_id`

#### Scenario: continuing a known conversation

- **WHEN** a caller sends `{"message": "And what about Black Lotus?", "conversation_id": "<known-uuid>"}`
- **THEN** the server SHALL append the new message to that conversation's history before invoking the agent; the response SHALL echo the same `conversation_id`

#### Scenario: empty message is rejected

- **WHEN** a caller sends `{"message": ""}` or `{"message": null}`
- **THEN** the server SHALL respond `422 Unprocessable Entity`; the agent loop SHALL NOT be invoked

#### Scenario: extra request fields are rejected

- **WHEN** a caller sends `{"message": "hi", "model_override": "gpt-4"}`
- **THEN** the server SHALL respond `422 Unprocessable Entity`; the agent loop SHALL NOT be invoked

#### Scenario: unknown conversation_id falls back to a fresh conversation

- **WHEN** a caller sends a `conversation_id` the server does not recognise (e.g., after a restart wiped the in-memory store)
- **THEN** the server SHALL allocate a fresh UUID4 instead of failing; the response SHALL carry the new id

### Requirement: POST /chat response body shape

When the request body is valid, the response SHALL be:

- Status: `200 OK`
- `Content-Type: application/json`
- Body: a JSON object with exactly the four fields below, in any key order:

| Field             | Type                       | Description                                                                                                |
|-------------------|----------------------------|------------------------------------------------------------------------------------------------------------|
| `response`        | string                     | The assistant's final text for this turn. MAY be the budget-exhausted message; SHALL never be empty.       |
| `conversation_id` | string                     | The active conversation id (freshly allocated or echoed from the request).                                 |
| `tool_calls`      | array of ToolCallTrace     | Per-turn trace of tool invocations, in the order the agent issued them. Default `[]` when no tool ran.     |
| `finish_reason`   | string \| null             | Subject to the `finish_reason` discipline defined below.                                                   |

No other fields SHALL appear in the response body. Adding a response-side field (e.g., `usage`, `model`, `latency_ms`) requires a MODIFIED delta on this requirement.

`finish_reason` discipline:

- The value MAY be `null` (provider did not produce a finish reason).
- The literal string `"budget_exhausted"` is RESERVED. `rbrain-cortex` SHALL emit it exactly when the ReAct loop terminated after exhausting its iteration budget without producing assistant text. No other condition SHALL produce this literal.
- Any other string value is OPAQUE: it carries the underlying LLM provider's `finish_reason` (e.g., `end_turn`, `tool_use`, `stop`, `length`, `max_tokens`, `tool_calls`) unchanged. Consumers SHALL NOT depend on the stability of opaque values across provider swaps or provider SDK upgrades.

#### Scenario: minimal text response

- **WHEN** the agent answers without invoking any tool and the provider reports a normal stop
- **THEN** the response SHALL be `{"response": "<text>", "conversation_id": "<uuid>", "tool_calls": [], "finish_reason": "<provider-defined>" or null}` with `tool_calls` empty and `response` non-empty

#### Scenario: budget_exhausted reservation

- **WHEN** the ReAct loop exits after its maximum iteration count without producing assistant text
- **THEN** `finish_reason` SHALL be the literal string `"budget_exhausted"`; `response` SHALL carry the budget-exhausted message defined in `cortex-bootstrap`; `tool_calls` SHALL contain the trace of every tool the loop invoked up to that point

#### Scenario: opaque provider value passthrough

- **WHEN** the underlying LLM provider returns a `finish_reason` of `"end_turn"` (anthropic), `"stop"` (openai or ollama), or any other provider-specific value
- **THEN** the response's `finish_reason` SHALL carry that string verbatim; no mapping or normalisation SHALL be applied at v1

#### Scenario: extra response fields are forbidden

- **WHEN** the response body is parsed
- **THEN** it SHALL NOT carry any field outside the four listed above; adding a fifth field requires an OpenSpec change against this requirement

### Requirement: tool_calls trace entries describe one tool invocation each

Each entry in the `tool_calls` array of the response body SHALL be a JSON object with exactly the three fields below, in any key order:

| Field         | Type   | Description                                                                                       |
|---------------|--------|---------------------------------------------------------------------------------------------------|
| `tool`        | string | The name of the tool the agent invoked (e.g., `"lookup_card"`, `"search_cards"`).                 |
| `args`        | object | The JSON arguments the LLM produced for the tool call, verbatim.                                  |
| `observation` | object | The structured payload the tool handler returned (success payload OR an `{"error": "..."}` shape).|

No other fields SHALL appear in a trace entry. The `tool_calls` array is flat: it lists every tool invocation across every ReAct iteration in the order they occurred, with no nesting and no per-iteration grouping.

#### Scenario: tool_calls is empty when no tool runs

- **WHEN** the agent answers without invoking any tool
- **THEN** the response's `tool_calls` array SHALL be the empty array `[]`; the `response` field SHALL carry the assistant's text

#### Scenario: one tool invocation produces one trace entry

- **WHEN** the agent invokes `lookup_card` once with `{"scryfall_id": "bd8fa327-..."}` and the handler returns the Black Lotus payload
- **THEN** `tool_calls` SHALL contain exactly one entry with `tool: "lookup_card"`, `args: {"scryfall_id": "bd8fa327-..."}`, and `observation` equal to the Card payload returned by the handler

#### Scenario: multiple invocations preserve order

- **WHEN** the agent invokes `search_cards` then `lookup_card` in the same turn (two ReAct iterations)
- **THEN** `tool_calls[0].tool` SHALL be `"search_cards"` and `tool_calls[1].tool` SHALL be `"lookup_card"`; the array order matches the invocation order

#### Scenario: tool error observation surfaces in the trace

- **WHEN** a tool returns a structured error observation (e.g., `{"error": "card not found", "scryfall_id": "..."}`)
- **THEN** `observation` in the matching trace entry SHALL carry that object verbatim; the trace SHALL NOT be redacted or summarised

#### Scenario: extra trace-entry fields are forbidden

- **WHEN** a trace entry is parsed
- **THEN** it SHALL NOT carry any field outside the three listed above; adding a fourth field requires an OpenSpec change against this requirement

### Requirement: No other public HTTP routes at v1

`rbrain-cortex` SHALL expose exactly two **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`) and `POST /chat` (defined here). Any additional public route — listing endpoints, batch endpoints, completions endpoints, websocket upgrades, conversation read endpoints — requires a MODIFIED delta on `cortex-api` before the route ships.

At v1, `rbrain-cortex` SHALL NOT expose any `/admin/*` route. Should an operator-only endpoint surface later (sync triggers, conversation purge, prompt overrides), an `/admin/*` carve-out comparable to `lexicon-api-admin-carveout` SHALL be introduced via its own OpenSpec change; only then are `/admin/*` routes permitted under this requirement.

#### Scenario: New public endpoint goes through OpenSpec

- **WHEN** a contributor adds `GET /conversations/{id}` or `POST /completions` to cortex
- **THEN** the change SHALL include a MODIFIED requirement on this spec; CI on cortex ALONE is not enough to make the new endpoint part of the public surface

#### Scenario: /health does not need a cortex-api requirement

- **WHEN** a contributor reads cortex-api/spec.md looking for `/health`
- **THEN** they SHALL find it referenced here as out-of-scope-for-this-capability and authoritative in `repository-conventions`; this spec SHALL NOT restate the `/health` contract

#### Scenario: Admin route requires a carve-out change first

- **WHEN** a contributor proposes `POST /admin/purge-conversations` against cortex
- **THEN** the change SHALL include both a new `/admin/*` carve-out requirement on `cortex-api` (mirroring `lexicon-api-admin-carveout`) AND the per-endpoint spec; merging the endpoint without the carve-out SHALL fail the closure clause
