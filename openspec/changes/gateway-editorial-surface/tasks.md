# Tasks — gateway-editorial-surface

Spec-only change; implementation follows in chronicle → gateway → deploy → app slices.

## 1. Verify before documenting

- [x] Confirm chronicle's admin handlers take `X-Author-Id` on create and act by id elsewhere, so the rewrite + header injection matches the real surface
- [x] Confirm gateway's `/admin/*` rejection is a hardcoded 404 preceding all routing, so the editorial surface cannot weaken it
- [x] Confirm `bounded-contexts` lists authorization beyond authentication as an identity non-responsibility, so the allowlist-at-gateway design is the catalogue-conformant one

## 2. Apply the deltas

- [ ] MODIFIED requirement headers match the canonical specs verbatim (gateway closure, gateway CORS, chronicle closure)
- [ ] `openspec validate gateway-editorial-surface --strict`
- [ ] `openspec archive gateway-editorial-surface -y`; verify the promoted specs (26-route closure, editorial requirement present, chronicle reachability wording amended)
- [ ] `bash scripts/validate-repo.sh .` and `bash scripts/validate-api-closure.sh` green
- [ ] Sync commit with an explicit path list; archive move in its own commit

## 3. Hand off

- [ ] Record the implementation order and why: chronicle (admin list/detail) BEFORE gateway (the rewrite targets those routes) BEFORE deploy (`ADMIN_USER_IDS`) BEFORE app (editor UI)
- [ ] Record that `GET /editorial/articles/{id}` requires chronicle's new `GET /admin/articles/{id}` — the gateway slice cannot ship first
