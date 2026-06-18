## 1. Contract (rbrain-codex)

- [ ] 1.1 chronicle-api: ADD public payloads (`Article`, `ArticleSummary`), `GET /articles` (paginated, published-only), `GET /articles/{slug}`, and the public-route closure with the `/admin/*` carve-out.
- [ ] 1.2 gateway-api: ADD "proxies chronicle blog reads unauthenticated"; MODIFY closure sixteen → eighteen; MODIFY CORS preflight to cover `/articles`, `/articles/{slug}`.
- [ ] 1.3 service-topology: MODIFY the call-graph requirement — narrow `gateway → chronicle` to reads-only.
- [ ] 1.4 `openspec validate chronicle-api --strict` passes.

## 2. Archive

- [ ] 2.1 Push planning commit.
- [ ] 2.2 Archive + `git add -A openspec/`; promote canonical chronicle-api / gateway-api / service-topology.
- [ ] 2.3 Update `service-topology/sync-graph.yaml`: narrow the `gateway → chronicle` edge `purpose` to reads-only (operator-internal authoring). Run `validate-topology.sh`.
- [ ] 2.4 Push the archive commit.

## 3. Implementations (sibling changes)

- [ ] 3.1 `rbrain-chronicle` `chronicle-blog-reads`: `ArticleStore` (published query, slug lookup), `GET /articles` (pagination + 400s), `GET /articles/{slug}` (404 for draft/absent), public payload serialization excluding internal fields; tests.
- [ ] 3.2 `rbrain-chronicle` `chronicle-authoring` (operator-internal): `/admin/articles/*` draft create/update, `POST /admin/articles/{id}/publish` (assigns slug + published_at), delete; lives in chronicle's own capability spec, not codex.
- [ ] 3.3 `rbrain-gateway` `gateway-chronicle-reads`: unauthenticated proxy for `GET /articles`, `GET /articles/{slug}`; CORS preflight for both; spec MODIFY mirror; tests.
- [ ] 3.4 `rbrain-app` `app-blog-reader`: blog index + article page consuming `GET /articles` and `GET /articles/{slug}`.
