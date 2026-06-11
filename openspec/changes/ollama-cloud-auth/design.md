## Context

The platform's stack spec declared three LLM providers from day one: Claude (Anthropic SDK), OpenAI (OpenAI SDK), and Ollama (HTTP). At spec time, Ollama meant a local instance with no auth — so `OLLAMA_BASE_URL` + `OLLAMA_MODEL` was the full env surface. Ollama Cloud's launch (and our adoption of `gpt-oss:120b-cloud` as the first cortex inference target) introduced a Bearer-token auth path that the catalog never enumerated.

This is a documentation-grade contract update. No new behavior beyond what cortex already implements.

## Goals / Non-Goals

**Goals:**

- Bring `providers.yaml` in line with the running cortex code so `validate-llm-config.sh` and any future tooling sees the canonical env var set.
- Keep `OLLAMA_API_KEY` optional so a local ollama deployment continues to work with no auth.

**Non-Goals:**

- Renaming, deprecating, or introducing a separate `ollama-cloud` provider key. Cloud is just Ollama with a header.
- Imposing a specific cloud URL. `OLLAMA_BASE_URL` already covers that.
- Mandating auth. Local-instance users would be locked out.

## Decisions

### D1. `OLLAMA_API_KEY` lives under `ollama.env.optional`

Adding under `optional` (vs. `required`) preserves backwards compatibility: existing local deployments without an API key continue to work. Cloud deployments set both `OLLAMA_BASE_URL=https://ollama.com` and `OLLAMA_API_KEY`.

**Rationale:** Minimal contract change for the largest deployment-flexibility win.

**Alternatives considered:**

- **Required** — rejected: would break every local ollama setup.
- **A new `ollama-cloud` provider** — rejected: duplicate SDK glue, doubles the surface, no real benefit. The header gate is a single line.

### D2. The MODIFIED requirement clarifies the wire format

The spec already says OllamaProvider is "backed by HTTP calls to a configurable Ollama endpoint." The MODIFIED requirement appends a sentence: "When `OLLAMA_API_KEY` is set, the provider SHALL include it as a `Bearer` token in the `Authorization` header on every request; when unset, the header SHALL be omitted." Tight, unambiguous, matches Ollama Cloud's own documentation.

## Risks / Trade-offs

- **Env var sprawl over time.** Each provider could grow a long optional list as their SDKs gain features. Mitigation: review at each addition; if a provider list exceeds ~5 optional vars, consider a sub-catalog file.
- **Cloud vs local feature parity.** Some Ollama Cloud models support tool calling differently from local ones. Out of scope here; cortex's provider already returns the tool calls the model surfaces.

## Migration Plan

No migration. Existing deployments are unaffected — they don't set `OLLAMA_API_KEY` and the provider doesn't include the header. The codex YAML update is purely additive.

## Open Questions

- **Should `validate-llm-config.sh` enforce that any env var named in providers.yaml exists in cortex AGENTS.md (or vice versa)?** Possibly worth a future helper. Not in scope here.
