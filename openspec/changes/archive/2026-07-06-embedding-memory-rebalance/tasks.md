## 1. Contract (rbrain-codex)

- [ ] 1.1 language-runtimes: MODIFY budgets (oracle 160, cortex 176, notes) + ceiling sums (998/26).
- [ ] 1.2 memory-budgets.yaml aligned; `validate-runtimes.sh` + `openspec validate --strict` pass.

## 2. Archive

- [ ] 2.1 Push planning commit; archive; push archive commit.

## 3. Downstream (sibling commits)

- [ ] 3.1 rbrain-oracle OWNERSHIP.yaml `max_rss_mb: 160`; rbrain-cortex OWNERSHIP.yaml `max_rss_mb: 176`.
- [ ] 3.2 rbrain-deploy compose: oracle `mem_limit: 160m`, cortex `mem_limit: 176m`.
- [ ] 3.3 Runtime re-verification at the new cortex limit happens with the oracle-semantic-search smoke (next bring-up).
