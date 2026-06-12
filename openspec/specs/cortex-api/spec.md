# cortex-api Specification

## Purpose
TBD - created by archiving change cortex-api. Update Purpose after archive.
## Requirements
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
| `finish_reason`   | enum or null               | Subject to the `finish_reason` enum and normalisation rules defined below.                                 |

No other fields SHALL appear in the response body. Adding a response-side field (e.g., `usage`, `model`, `latency_ms`) requires a MODIFIED delta on this requirement.

`finish_reason` enum:

The value SHALL be either `null` or one of exactly five string literals:

| Value               | Meaning                                                                                                            |
|---------------------|--------------------------------------------------------------------------------------------------------------------|
| `null`              | The underlying provider did not produce a finish_reason at all (e.g., malformed provider response).                |
| `"stop"`            | The model finished its response normally and did not request a tool call.                                          |
| `"tool_use"`        | The model's final action was to request one or more tool calls (final iteration was tool-bound, not text-bound).   |
| `"length"`          | The response was truncated because the model hit a token / context length cap on the provider side.                |
| `"budget_exhausted"`| Cortex's ReAct loop terminated after exhausting its iteration budget without producing assistant text.             |
| `"other"`           | The provider returned a finish_reason value not covered by the four buckets above (e.g., refusal, content filter). |

`"budget_exhausted"` SHALL be emitted exclusively by cortex's loop terminator; provider-side mappings SHALL NOT produce this literal. The other four buckets and `null` are reachable only via the normalisation table specified in the companion requirement "finish_reason normalisation is provider-agnostic".

#### Scenario: minimal text response

- **WHEN** the agent answers without invoking any tool and the provider reports a normal stop
- **THEN** the response SHALL be `{"response": "<text>", "conversation_id": "<uuid>", "tool_calls": [], "finish_reason": "stop"}` with `tool_calls` empty and `response` non-empty

#### Scenario: budget_exhausted reservation

- **WHEN** the ReAct loop exits after its maximum iteration count without producing assistant text
- **THEN** `finish_reason` SHALL be the literal string `"budget_exhausted"`; `response` SHALL carry the budget-exhausted message defined in `cortex-bootstrap`; `tool_calls` SHALL contain the trace of every tool the loop invoked up to that point

#### Scenario: finish_reason is one of the closed enum values or null

- **WHEN** the response body is parsed
- **THEN** `finish_reason` SHALL be exactly one of `null`, `"stop"`, `"tool_use"`, `"length"`, `"budget_exhausted"`, `"other"`; any other string value indicates a violation of this requirement

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

### Requirement: finish_reason normalisation is provider-agnostic

`rbrain-cortex` SHALL normalise the underlying LLM provider's `finish_reason` value to the closed enum defined by "POST /chat response body shape" before serialising the HTTP response. The normalisation SHALL be a pure transformation depending only on the raw value; provider identity SHALL NOT be a parameter (the union of documented provider values is collision-free at v1).

The mapping table SHALL be:

| Raw provider value           | Source provider(s)            | Normalised value      |
|------------------------------|-------------------------------|-----------------------|
| `end_turn`                   | anthropic                     | `"stop"`              |
| `stop`                       | openai, ollama                | `"stop"`              |
| `stop_sequence`              | anthropic                     | `"stop"`              |
| `tool_use`                   | anthropic                     | `"tool_use"`          |
| `tool_calls`                 | openai, ollama                | `"tool_use"`          |
| `function_call` (deprecated) | openai                        | `"tool_use"`          |
| `max_tokens`                 | anthropic                     | `"length"`            |
| `length`                     | openai, ollama                | `"length"`            |
| `budget_exhausted`           | cortex (loop terminator)      | `"budget_exhausted"`  |
| `null` / absent              | any                           | `null`                |
| Any other string value       | any (incl. future SDK values) | `"other"`             |

The cortex-injected `"budget_exhausted"` literal SHALL survive normalisation unchanged: it is its own input and its own output.

When the normaliser encounters a raw value that does not appear in the table above and is not `null`, it SHALL emit exactly one structured WARN log carrying the unknown value (so operators can extend the mapping in a follow-up change) and SHALL return `"other"`. The normaliser SHALL NOT raise.

Adding, renaming, or removing rows in the mapping table requires a MODIFIED delta on this requirement.

#### Scenario: anthropic end_turn maps to stop

- **WHEN** the underlying anthropic provider returns `finish_reason="end_turn"`
- **THEN** the cortex HTTP response SHALL carry `"finish_reason": "stop"`

#### Scenario: openai and ollama tool_calls map to tool_use

- **WHEN** an openai or ollama provider returns `finish_reason="tool_calls"` (or anthropic returns `"tool_use"`)
- **THEN** the cortex HTTP response SHALL carry `"finish_reason": "tool_use"`

#### Scenario: length caps from any provider collapse into length

- **WHEN** anthropic returns `"max_tokens"`, openai returns `"length"`, or ollama returns `"length"`
- **THEN** the cortex HTTP response SHALL carry `"finish_reason": "length"`

#### Scenario: cortex-injected budget_exhausted passes through unchanged

- **WHEN** the ReAct loop emits `"budget_exhausted"` via its own terminator (no provider involvement)
- **THEN** the cortex HTTP response SHALL carry `"finish_reason": "budget_exhausted"` verbatim; the normaliser SHALL NOT alter it

#### Scenario: unknown provider value falls through to other with a warning

- **WHEN** the provider returns a value the mapping table does not cover (e.g., anthropic's `"pause_turn"`, openai's `"content_filter"`, anthropic's `"refusal"`, or a value introduced by a future SDK release)
- **THEN** the cortex HTTP response SHALL carry `"finish_reason": "other"`; the normaliser SHALL emit one structured WARN log naming the unknown value; the agent loop SHALL NOT raise

#### Scenario: null provider value preserves null

- **WHEN** the provider does not produce a finish_reason at all (the raw value is `null` or absent)
- **THEN** the cortex HTTP response SHALL carry `"finish_reason": null`; the normaliser SHALL NOT default to `"other"`

