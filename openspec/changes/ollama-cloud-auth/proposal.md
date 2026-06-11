## Why

`rbrain-cortex` shipped its first slice (`cortex-bootstrap`) running against Ollama Cloud (`https://ollama.com`) as its production-tier inference provider. Ollama Cloud gates access with a Bearer token in the `Authorization` header — exactly the kind of provider-specific environment variable that the `llm-abstraction` capability says MUST be declared in `providers.yaml`. The provider code in cortex grew an optional `OLLAMA_API_KEY` env var (commit `e48e58f` in `rbrain-cortex`) but the codex catalog still lists `ollama.env.optional: []`, so the contract and the running code disagree.

This change closes that gap: lists `OLLAMA_API_KEY` as an optional env var for the ollama provider in `providers.yaml`, and updates the `Three reference providers ship in v1` requirement on `llm-abstraction` to mention the cloud-vs-local distinction.

## What Changes

- Add `OLLAMA_API_KEY` to `providers.yaml` under `ollama.env.optional`.
- MODIFY the `Three reference providers ship in v1` requirement on `llm-abstraction` to clarify that `OllamaProvider` SHALL transmit `OLLAMA_API_KEY` as a `Bearer` token in the `Authorization` header when the variable is set (and omit the header when unset, the local-instance default).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `llm-abstraction`: extend the OllamaProvider description with the optional Bearer auth contract.

## Impact

- **`rbrain-codex`**: one YAML field added to `providers.yaml`, one MODIFIED Requirement on `llm-abstraction`.
- **`rbrain-cortex`**: already implements the contract (commit `e48e58f`); a brief AGENTS.md note documenting the env var lands as a follow-up commit in that repo (tracked in tasks, not part of this codex change).
- **Out of scope**:
  - Promoting `OLLAMA_API_KEY` to required. Local ollama instances are still valid and need no auth.
  - Adding cloud-specific provider variants (`OllamaCloudProvider`). Same SDK, same code path, just a header.
  - Multi-tier auth (per-user keys, key rotation, etc.). Future ops slice.
