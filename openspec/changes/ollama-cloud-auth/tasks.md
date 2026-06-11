## 1. providers.yaml update

- [x] 1.1 Add `OLLAMA_API_KEY` to `openspec/specs/llm-abstraction/providers.yaml` under `ollama.env.optional`.
- [x] 1.2 Run `bash scripts/validate-llm-config.sh` locally to confirm the catalog still validates (exactly three providers, each with at least one required env var).

## 2. Hand-off

- [ ] 2.1 Commit, push, and confirm CI on `rbrain-codex` stays green.
- [ ] 2.2 Archive this change via `openspec archive ollama-cloud-auth`.
- [ ] 2.3 Follow-up in `rbrain-cortex`: update `AGENTS.md` to mention `OLLAMA_API_KEY` in the provider env enumeration. Tracked here for traceability; the commit lives in cortex.
