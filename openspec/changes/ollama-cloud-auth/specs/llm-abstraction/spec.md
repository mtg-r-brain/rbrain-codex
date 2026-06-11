## MODIFIED Requirements

### Requirement: Three reference providers ship in v1

`rbrain-cortex` SHALL include first-class implementations of `LlmPort` for the three providers below. These implementations SHALL be packaged with the service (no external plugin loading at v1):

- `ClaudeProvider` — backed by the official `anthropic` Python SDK
- `OllamaProvider` — backed by HTTP calls to a configurable Ollama endpoint. When the optional `OLLAMA_API_KEY` environment variable is set, the provider SHALL include it as a `Bearer` token in the `Authorization` header on every request (enabling Ollama Cloud and any other gated deployment). When `OLLAMA_API_KEY` is unset, the header SHALL be omitted, matching the local-instance default.
- `OpenAiProvider` — backed by the official `openai` Python SDK

#### Scenario: Selecting any of the three at deployment

- **WHEN** a deployment configures `LLM_PROVIDER=ollama` and a valid `OLLAMA_BASE_URL`
- **THEN** `rbrain-cortex` SHALL start and use the Ollama provider for all `LlmPort` calls

#### Scenario: Removing a reference provider requires a spec change

- **WHEN** a contributor proposes deleting one of the three reference providers
- **THEN** the proposal SHALL be rejected unless it amends this requirement via an OpenSpec change

#### Scenario: Ollama Cloud auth flows via OLLAMA_API_KEY

- **WHEN** a deployment configures `LLM_PROVIDER=ollama`, `OLLAMA_BASE_URL=https://ollama.com`, and `OLLAMA_API_KEY=<token>`
- **THEN** every request the provider issues SHALL carry `Authorization: Bearer <token>`; the local-instance code path (no `OLLAMA_API_KEY`) SHALL remain unchanged
