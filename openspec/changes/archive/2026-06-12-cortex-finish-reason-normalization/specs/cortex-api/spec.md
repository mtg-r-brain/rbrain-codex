## MODIFIED Requirements

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

## ADDED Requirements

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
