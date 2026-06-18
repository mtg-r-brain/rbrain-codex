## Why

`rbrain-chronicle` is the only bounded context provisioned end-to-end at the platform layer — `bounded-contexts` catalog, `language-runtimes` (rust, 25 MB), `data-stores` (the `chronicle` PostgreSQL schema), the `gateway → chronicle` topology edge, and a checked-in scaffold baseline — yet it has **no API contract**. Every other topology callee ships a `<context>-api/spec.md`; chronicle is the sole exception, leaving the last open edge of the call graph unspecified.

This change defines `chronicle-api` v1: the **public blog reads** that the `gateway → chronicle` edge promises. Editorial authoring is deliberately **operator-internal** — it lives under chronicle's reserved `/admin/*` prefix (per the `lexicon-api-admin-carveout` precedent), is NOT proxied by the gateway, and its detailed behavior belongs to `rbrain-chronicle`'s own authoring capability, not to this public contract. Chronicle is an editorial blog (staff-authored content, public readership); operator-internal authoring matches that reality and avoids amending identity's frozen JWT claims contract for a platform-wide RBAC role no other context needs yet.

## What Changes

- ADD a `chronicle-api` capability with:
  - "Public article list endpoint" — `GET /articles`, paginated (`limit`/`offset`), **published articles only**, newest first, in a `results`/`has_more`/`limit`/`offset` envelope mirroring `lexicon-api`'s `GET /cards`.
  - "Public single-article endpoint" — `GET /articles/{slug}`, returning a published article by slug; `404` for a draft or unknown slug.
  - "Public article payloads" — the `Article` and `ArticleSummary` JSON shapes.
  - "No other public HTTP routes at v1" — exactly `GET /health` + the two read routes; authoring routes live under the `/admin/*` carve-out and do NOT count.
- MODIFY `gateway-api`:
  - ADD "rbrain-gateway proxies chronicle blog reads unauthenticated" — `GET /articles`, `GET /articles/{slug}` as pass-through **unauthenticated** proxies to chronicle (blog reads are public, like the identity auth proxies are public).
  - MODIFY "No other public HTTP routes at v1": sixteen → **eighteen** (add the two read routes).
  - MODIFY "CORS preflight discipline": add `/articles` and `/articles/{slug}` to the preflight set and the uniform-coverage list.
- MODIFY `service-topology` "Authoritative synchronous call graph": narrow the `gateway → chronicle` edge purpose to **reads only** — authoring is operator-internal under chronicle's `/admin/*`, not gateway-proxied. The edge itself is unchanged (gateway still calls chronicle for reads); the DAG is unchanged. `sync-graph.yaml`'s edge `purpose` is updated to match.

## Capabilities

### New Capabilities

- `chronicle-api`: the public HTTP contract for chronicle — blog read routes, payloads, and the closed public-route set.

### Modified Capabilities

- `gateway-api`: chronicle public reads added (unauthenticated proxy); closure sixteen → eighteen; CORS extended.
- `service-topology`: `gateway → chronicle` edge narrowed to reads (authoring is operator-internal).

## Impact

- **Contract only** here. Implementation lands in a sibling `rbrain-chronicle` change (handlers, `ArticleStore`, draft→publish lifecycle behind `/admin/*`) and a `rbrain-gateway` change (two unauthenticated proxy routes).
- **No new sync edge** (`gateway → chronicle` already exists; this is its first concrete use). **No NATS.** **No new schema** (the `chronicle` PostgreSQL role/schema already exists in `data-stores`).
- **No identity-api change** — Path B avoids touching the frozen JWT claims contract. A platform RBAC role (`role` claim) remains a future option if multiple contexts later need editorial/author/moderator roles.
- **Specs touched**: codex `chronicle-api` (new), `gateway-api`, `service-topology`.
