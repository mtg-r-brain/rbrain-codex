## Why

The first full-platform run (rbrain-deploy compose stack, 2026-07-06) refuted identity's 25 MB memory budget empirically: `POST /auth/register` OOM-kills the identity process mid-request, every time. The cause is structural, not a leak — the committed `identity-bootstrap-mvp` spec mandates Argon2id with explicit OWASP parameters (`m=65536`), and `m` is a **memory** cost: every password hash transiently allocates 64 MiB by design. A 25 MB ceiling makes the service's core operation impossible; steady-state RSS (~3.5 MB) was never the problem.

Evidence from the live stack: with `mem_limit: 25m`, register → connection drop (`hyper IncompleteMessage` at the gateway, container restart count increments, zero application logs — SIGKILL). With the limit raised, the same request → `201` and RSS settles back to 3.4 MiB.

## What Changes

- MODIFY `language-runtimes` "Per-context memory budget": `identity` 25 → **96** (64 MiB Argon2id working set + baseline + headroom for one in-flight hash; concurrent hashes are serialized by the wallclock cost of Argon2 in practice at demo scale — revisit if registration throughput becomes a requirement).
- MODIFY `language-runtimes` "Platform-wide memory ceiling": current sum 831 → **902 MB**, headroom 193 → **122 MB** (ceiling unchanged at 1024).
- Update `memory-budgets.yaml` accordingly (budgets sum comment 485 → 556).
- Downstream (sibling commits, not OpenSpec changes): `rbrain-identity/OWNERSHIP.yaml` `max_rss_mb: 96`; `rbrain-deploy` compose `mem_limit: 96m` for identity.

## Capabilities

### Modified Capabilities

- `language-runtimes`: identity budget aligned with its own password-hashing contract.

## Impact

- No code change. `validate-runtimes.sh` recomputes the sum (902 ≤ 1024). The frugality posture stands — the budget now reflects the security spec the platform already committed to.
