## Why

The platform's depth pivot starts with semantic rules search in oracle, and the chosen embedding rail (decision 2026-07-06, user-validated) is **in-process ONNX inference** — sovereign, offline, no per-query network hop; Ollama Cloud's catalogue ships no embedding model, and an external embeddings vendor contradicts the platform's sovereignty posture. In-process inference does not fit oracle's 40 MB budget.

A dedicated spike (fastembed-rs, quantized MiniLM-L6-v2, 384 dims, 2026-07-06) measured on the target corpus size (3430 rules):

- serving steady state (model loaded + query embedding): **~102 MiB** peak RSS;
- sync-time indexation transient (batch 8): **~115 MiB** peak, full corpus embedded in 41 s;
- single query embedding: **~3 ms**.

Meanwhile cortex's 200 MB budget is empirically oversized: live agent smokes (2026-07-06, full stack) show **93 MiB** steady state.

## What Changes

- MODIFY `language-runtimes` "Per-context memory budget": `oracle` 40 → **160** (in-process embedding note, mirroring the identity/Argon2id precedent for spec-mandated working sets), `cortex` 200 → **176** (empirical headroom note).
- MODIFY `language-runtimes` "Platform-wide memory ceiling": current sum 902 → **998 MB**, headroom 122 → **26 MB** (ceiling unchanged at 1024).
- Update `memory-budgets.yaml` (budgets sum 556 → 652).
- Downstream (sibling commits): `rbrain-oracle`/`rbrain-cortex` `OWNERSHIP.yaml`; `rbrain-deploy` compose `mem_limit`s.

## Capabilities

### Modified Capabilities

- `language-runtimes`: budgets aligned with the embedding rail decision and live measurements.

## Impact

- No code change here; the oracle implementation lands behind `oracle-semantic-search`. Headroom shrinks to 26 MB — the next budget request forces either optimization or a deliberate ceiling amendment.
