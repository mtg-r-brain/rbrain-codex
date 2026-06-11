# llm-abstraction Specification

## Purpose
TBD - created by archiving change technology-stack. Update Purpose after archive.
## Requirements
### Requirement: LlmPort abstracts every LLM interaction in cortex

`rbrain-cortex` SHALL expose a single abstraction named `LlmPort` through which every LLM invocation passes. Code in `rbrain-cortex` SHALL NOT call provider-specific SDKs directly outside of the provider implementations (`ClaudeProvider`, `OllamaProvider`, `OpenAiProvider`); all higher-level orchestration code SHALL depend on `LlmPort` only.

#### Scenario: Direct SDK use outside a provider is rejected

- **WHEN** any module in `rbrain-cortex` outside the `providers/` package imports `anthropic`, `openai`, or `ollama` and uses it for inference
- **THEN** linting or CI SHALL reject the build with a message pointing at this requirement

#### Scenario: New provider integration

- **WHEN** a contributor wants to add a fourth provider (e.g. Mistral, Gemini)
- **THEN** they SHALL implement the new provider as an `LlmPort` implementation under `providers/` and SHALL NOT introduce SDK calls elsewhere

### Requirement: LlmPort exposes generation, tool-calling, and embeddings

`LlmPort` SHALL expose at least the following three capabilities, each as a distinct method or operation:

- **generation**: produce a free-form response given a prompt and conversation history
- **tool-calling**: produce a tool-invocation decision given a prompt and a list of tool descriptors
- **embeddings**: produce vector embeddings for a batch of texts

Method signatures, parameter types, and return types are an implementation detail of `rbrain-cortex` and are NOT specified here.

#### Scenario: A provider missing a capability fails at boot

- **WHEN** a provider implementation is selected at boot but does not implement one of the three capabilities (e.g. an embeddings-less provider)
- **THEN** `rbrain-cortex` SHALL fail to start with a clear error naming the missing capability

#### Scenario: Higher-level code can rely on all three capabilities

- **WHEN** orchestration code calls `LlmPort` for tool-calling
- **THEN** the call SHALL be honored regardless of which configured provider is active, or SHALL fail with a structured error if the provider's API does not support tool-calling

### Requirement: Three reference providers ship in v1

`rbrain-cortex` SHALL include first-class implementations of `LlmPort` for the three providers below. These implementations SHALL be packaged with the service (no external plugin loading at v1):

- `ClaudeProvider` — backed by the official `anthropic` Python SDK
- `OllamaProvider` — backed by HTTP calls to a configurable Ollama endpoint
- `OpenAiProvider` — backed by the official `openai` Python SDK

#### Scenario: Selecting any of the three at deployment

- **WHEN** a deployment configures `LLM_PROVIDER=ollama` and a valid `OLLAMA_BASE_URL`
- **THEN** `rbrain-cortex` SHALL start and use the Ollama provider for all `LlmPort` calls

#### Scenario: Removing a reference provider requires a spec change

- **WHEN** a contributor proposes deleting one of the three reference providers
- **THEN** the proposal SHALL be rejected unless it amends this requirement via an OpenSpec change

### Requirement: No default provider; explicit configuration required

`rbrain-cortex` SHALL NOT ship with a default `LLM_PROVIDER`. Starting the service without an explicit `LLM_PROVIDER` environment variable, or with a value outside `claude | ollama | openai`, SHALL fail at boot with a clear error message naming the accepted values.

#### Scenario: Missing configuration fails at boot

- **WHEN** `rbrain-cortex` is started without setting `LLM_PROVIDER`
- **THEN** the service SHALL exit with a non-zero status before opening any port, and the error message SHALL list the accepted values

#### Scenario: Provider-specific credentials are required for the chosen provider

- **WHEN** `LLM_PROVIDER=claude` is set but `ANTHROPIC_API_KEY` is unset
- **THEN** the service SHALL fail at boot rather than at first inference request

### Requirement: Provider configuration is declared, not implicit

The set of supported configuration variables for each provider SHALL be declared in `rbrain-cortex/AGENTS.md` and SHALL be the only environment variables the providers read. Hidden or undocumented configuration sources SHALL be forbidden.

#### Scenario: Undocumented env var is forbidden

- **WHEN** a contributor wires a provider implementation to read an env var not listed in `rbrain-cortex/AGENTS.md`
- **THEN** code review SHALL require updating `AGENTS.md` in the same change, or removing the env var

