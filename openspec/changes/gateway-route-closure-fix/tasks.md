## 1. Contract (rbrain-codex)

- [ ] 1.1 gateway-api: MODIFY "No other public HTTP routes at v1" — count eleven → sixteen; enumerate the five `/decks/*` routes.
- [ ] 1.2 gateway-api: MODIFY "CORS preflight discipline" — add the five `/decks/*` routes to the preflight set and the uniform-coverage list.
- [ ] 1.3 `openspec validate gateway-route-closure-fix --strict` passes.

## 2. Archive

- [ ] 2.1 Push planning commit.
- [ ] 2.2 Archive + `git add -A openspec/`; promote canonical gateway-api.
- [ ] 2.3 Push the archive commit.

## 3. Sibling follow-up (verification, not contract)

- [ ] 3.1 `rbrain-gateway`: confirm the CORS layer actually preflights `/decks/*` (`OPTIONS /decks`, `OPTIONS /decks/{id}` with `PUT`/`DELETE`). If missing, open a `gateway-cors-decks` implementation change. No codex change needed — this contract already requires it.
