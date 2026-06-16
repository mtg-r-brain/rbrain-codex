## 1. Contract (rbrain-codex)

- [x] 1.1 MODIFY `gateway-api` auth-route proxy requirement — add the two Discord OAuth routes.
- [x] 1.2 MODIFY `gateway-api` "No other public HTTP routes at v1" — 9 → 11.
- [x] 1.3 `openspec validate gateway-oauth-discord --strict` passes.

## 2. Archive

- [x] 2.1 Push planning commit.
- [x] 2.2 Archive + `git add -A openspec/`; promote canonical `gateway-api`.
- [x] 2.3 Push the archive commit.

## 3. Implementation (sibling — rbrain-gateway change `gateway-oauth-discord`)

- [ ] 3.1 Register the two public GET Discord routes proxying to identity (redirect relay already in place).
