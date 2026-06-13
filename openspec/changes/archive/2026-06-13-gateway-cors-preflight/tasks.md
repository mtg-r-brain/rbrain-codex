## 1. Spec delta

- [x] 1.1 `openspec/specs/gateway-api/spec.md` — append `Requirement: CORS preflight discipline` with 4 scenarios (allowlisted preflight, non-allowlisted preflight, empty allowlist, preflight bypasses JWT).

## 2. Sibling slice

- [x] 2.1 `rbrain-gateway/openspec/changes/gateway-cors-policy/` shipped in lockstep — codex contract is now observable in the gateway impl.

## 3. CI + archive

- [x] 3.1 Push planning commits; verify CI green.
- [ ] 3.2 Archive via git mv to `openspec/changes/archive/2026-06-13-gateway-cors-preflight/`, promote the ADDED Requirement into `openspec/specs/gateway-api/spec.md` (append).
- [ ] 3.3 Push the archive commit; verify CI stays green.
