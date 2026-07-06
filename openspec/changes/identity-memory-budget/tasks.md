## 1. Contract (rbrain-codex)

- [ ] 1.1 language-runtimes: MODIFY "Per-context memory budget" (identity 25 → 96, transient-allocation note, new scenario) and "Platform-wide memory ceiling" (sum 902, headroom 122).
- [ ] 1.2 memory-budgets.yaml: identity 96; comments — budgets sum 556, total 902, headroom 122.
- [ ] 1.3 `openspec validate identity-memory-budget --strict` + `validate-runtimes.sh` pass.

## 2. Archive

- [ ] 2.1 Push planning commit; archive; push archive commit.

## 3. Downstream (sibling commits)

- [ ] 3.1 rbrain-identity: OWNERSHIP.yaml `max_rss_mb: 96`.
- [ ] 3.2 rbrain-deploy: compose `mem_limit: 96m` for identity; recreate; verify register → 201 at the spec'd limit.
