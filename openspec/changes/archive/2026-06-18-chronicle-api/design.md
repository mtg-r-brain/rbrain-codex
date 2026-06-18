## Context

`rbrain-chronicle` is provisioned across every platform layer (catalog, runtime, memory budget, PostgreSQL schema, topology edge, scaffold baseline) but has no HTTP contract — the sole topology callee without a `<context>-api` spec. This change defines its public surface. The `gateway → chronicle` edge promises "reads (public) and edits (authenticated)"; this design decides how each half is realized.

## Decisions

### Authoring is operator-internal (Path B), not gateway-fronted

The decisive constraint: `identity-api`'s JWT claims contract is frozen to exactly `{sub, email, iat, exp}` with custom claims explicitly forbidden. A user-facing "author" role would require amending that frozen contract plus gateway propagation — a platform-wide RBAC change for a role no other context needs yet.

Chronicle is an **editorial** blog (staff-authored content, public readership), so authoring naturally fits the `lexicon-api-admin-carveout` precedent: authoring routes live under chronicle's reserved `/admin/articles/*`, are operator/platform-internal, are NOT proxied by the gateway, and their detailed behavior belongs to `rbrain-chronicle`'s own authoring capability — exactly as `scryfall-sync`'s `/admin/sync` lives in `rbrain-lexicon`, not in `lexicon-api`.

Consequence: the `gateway → chronicle` edge narrows to **reads only**. The edge stays in the graph (gateway proxies reads); the DAG is unchanged.

Rejected — **Path A (JWT `role` claim)**: a proper platform RBAC foundation, but it touches three specs including identity's frozen contract and over-builds for a single editorial consumer. Kept as the documented future option if author/moderator/admin roles later span multiple contexts.

### Identifier scheme: slug public, UUID internal

Public reads are slug-addressed (`GET /articles/{slug}`) — blog URLs are slugs, SEO-friendly and human-readable. The internal UUID `id` (used by the operator-internal `/admin/*` mutation routes) is never exposed on the public surface. The `slug` is assigned at publication.

### Public payloads exclude all draft/internal fields

`Article` and `ArticleSummary` carry only reader-relevant fields. `id`, `author_id`, `status`, `updated_at` never appear publicly. A draft is indistinguishable from an absent article (`404`), so the public surface leaks nothing about unpublished work.

### Pagination mirrors lexicon

`GET /articles` reuses `lexicon-api`'s `results`/`has_more`/`limit`/`offset` envelope and the same `limit ∈ [1,100]` default-20 / `offset ≥ 0` validation, with `400 {"error", "param"}` on malformed input. One pagination idiom across the platform.

## Scope boundaries

- **In**: public read contract, gateway public-read proxy, topology edge narrowing, closure + CORS updates.
- **Out**: authoring behavior (lives in `rbrain-chronicle`'s authoring capability), comments/feeds/search/category indexes (future MODIFIED deltas), any identity/JWT change.

## Risks / Trade-offs

- **No browser self-service authoring** at v1 — acceptable for an editorial blog; revisited via Path A if community authoring is wanted.
- **Port map**: chronicle's `8084` is marked "reserved" in `service-topology`'s port map. Bringing the read API online activates it; "reserved" pre-allocates the number and does not forbid use, so the map is left untouched. The deploy slice wires the port.
- **`published_at` is ISO-8601**, diverging from identity's UNIX-timestamp claims — deliberate: content publication dates are conventionally ISO-8601 and human-facing, unlike token lifetimes.
