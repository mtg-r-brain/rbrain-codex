## 1. Contract (rbrain-codex)

- [ ] 1.1 MODIFY `gateway-api` "rbrain-gateway proxies the identity auth routes unauthenticated" — add the two Google OAuth GET routes + redirect/`Set-Cookie` relay-not-follow guarantee.
- [ ] 1.2 MODIFY `gateway-api` "No other public HTTP routes at v1" — 7 → 9 public routes.
- [ ] 1.3 `openspec validate gateway-oauth-routes --strict` passes.

## 2. Archive

- [ ] 2.1 Push planning commits.
- [ ] 2.2 Archive (`openspec archive` + `git add -A openspec/`) → `openspec/changes/archive/2026-06-16-gateway-oauth-routes/`; promote canonical `gateway-api`.
- [ ] 2.3 Push the archive commit.

## 3. Implementation (sibling — rbrain-gateway change `gateway-oauth-routes`)

- [ ] 3.1 Disable reqwest redirect-following on the proxy client (`redirect(Policy::none())`).
- [ ] 3.2 Register the two public GET routes proxying to identity (StripAuthOnly).
- [ ] 3.3 MODIFY gateway `gateway-bootstrap-mvp` (proxy relays redirects; auth-route set includes oauth) + wiremock test: 302 + Location + Set-Cookie relayed, not followed.
