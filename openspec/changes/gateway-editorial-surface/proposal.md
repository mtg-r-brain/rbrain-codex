## Why

The chronicle blog has a live public read chain but no authenticated way to write: authoring sits
on chronicle's operator-internal `/admin/*` surface, reachable only from inside the deployment
(lane 1, `chronicle-content-ops` in rbrain-deploy, made that gesture pleasant). Lane 2 of the
agreed chronicle plan is a real editor in the app — which needs the platform's front door to admit
editorial writes without breaking two standing rules: gateway rejects external `/admin/*` paths,
and identity deliberately owns no authorization beyond authentication.

## What Changes

- `gateway-api` gains an editorial surface: six `/editorial/articles*` routes, gated by the
  standard Bearer JWT AND membership of the verified `sub` in a deployment-configured
  `ADMIN_USER_IDS` allowlist (403 `{"error":"forbidden"}` otherwise — including when the list is
  empty, the default: closed until an operator opts in). Gated requests rewrite `/editorial/` →
  `/admin/` toward chronicle, injecting `X-Author-Id`/`X-User-Id` from the JWT `sub` (client
  values stripped). External `/admin/*` stays hardcoded-404.
- The public-route closure widens from twenty to twenty-six; the CORS enumeration gains the six
  routes and the method floor gains `PUT, DELETE` (editorial uses both from a browser).
- `chronicle-api`'s reachability sentence is amended: `/admin/*` PATHS remain unreachable through
  the gateway; the gateway MAY expose its own authenticated `/editorial/*` rewrite onto that
  surface. The trust decision lives at the gateway boundary; chronicle stays header-trusting
  behind it, exactly like forge with `X-User-Id`.
- Deliberately NOT role-based access control: no role claim in the JWT, no identity change —
  membership in an env-var list is an operational trust decision, consistent with
  `bounded-contexts` declaring authorization outside identity's responsibility.
- **BREAKING**: none. All six routes are new; every existing route, gate, and rejection is
  unchanged.

## Capabilities

### Modified Capabilities

- `gateway-api`: +1 requirement (editorial surface), closure 20 → 26, CORS enumeration + method
  floor widened.
- `chronicle-api`: the `/admin/*`-reachability wording admits the gateway's `/editorial/*` rewrite
  while keeping direct `/admin/*` paths dead.

## Impact

- `rbrain-codex`: the two spec files only.
- `rbrain-chronicle` (next slice): ADDED admin list/detail routes (`GET /admin/articles`,
  `GET /admin/articles/{id}`) in its own `chronicle-authoring` capability — the editor needs to
  list drafts and load one article's body; those routes are repo-local, not codex-contract.
- `rbrain-gateway` (after chronicle): implement the surface + wiremock tests.
- `rbrain-deploy` (chore): wire `ADMIN_USER_IDS` on the gateway service, document how an operator
  finds their user id.
- `rbrain-app` (last): `/editorial` page — list, edit, publish, delete.
