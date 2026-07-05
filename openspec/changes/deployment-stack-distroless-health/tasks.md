## 1. Contract (rbrain-codex)

- [ ] 1.1 deployment-stack: MODIFY "Health-gated startup ordering" — infra healthchecks mandatory, in-container service probes only where the image can execute one, distroless exempt (host-side sweep asserts their health).
- [ ] 1.2 `openspec validate deployment-stack-distroless-health --strict` passes.

## 2. Archive

- [ ] 2.1 Push planning commit.
- [ ] 2.2 Archive + `git add -A openspec/`; promote the modified requirement.
- [ ] 2.3 Push the archive commit.
