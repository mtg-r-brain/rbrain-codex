# chronicle-api Specification

## Purpose
TBD - created by archiving change chronicle-api. Update Purpose after archive.
## Requirements
### Requirement: Public article payloads

`rbrain-chronicle` SHALL expose two public JSON shapes for blog reads.

An `Article` (returned by `GET /articles/{slug}`) SHALL carry exactly these fields:

| Field          | Type   | Description                                                          |
|----------------|--------|---------------------------------------------------------------------|
| `slug`         | string | URL-safe unique identifier, assigned at publication.                |
| `title`        | string | Article title.                                                      |
| `body`         | string | Article body as Markdown source (rendering is the reader's concern).|
| `category`     | string | Single category label the article belongs to.                       |
| `published_at` | string | Publication instant as an ISO-8601 UTC timestamp (`...Z`).          |

An `ArticleSummary` (each entry of `GET /articles`) SHALL carry exactly these fields:

| Field          | Type   | Description                                                          |
|----------------|--------|---------------------------------------------------------------------|
| `slug`         | string | As above.                                                           |
| `title`        | string | As above.                                                           |
| `excerpt`      | string | Short plain-text summary derived from the body.                     |
| `category`     | string | As above.                                                           |
| `published_at` | string | As above.                                                           |

Neither shape SHALL expose draft-only fields: internal `id` (UUID), `author_id`, `updated_at`, or draft `status` are NOT part of any public payload. Drafts are never represented in a public response.

#### Scenario: Article omits internal fields

- **WHEN** a published article is returned by `GET /articles/{slug}`
- **THEN** the body SHALL contain exactly `slug`, `title`, `body`, `category`, `published_at`; no `id`, `author_id`, `status`, or `updated_at` SHALL appear

### Requirement: Public article list endpoint

`rbrain-chronicle` SHALL expose `GET /articles` on its declared service port, returning **published articles only**, ordered by `published_at` descending (newest first). Drafts SHALL NEVER appear.

The endpoint SHALL accept two optional query parameters:

- `limit` — page size, integer in `[1, 100]`, default `20`.
- `offset` — number of leading results to skip, non-negative integer, default `0`.

The `200 OK` response SHALL be `Content-Type: application/json` with exactly four top-level fields:

| Field      | Type                   | Description                                                      |
|------------|------------------------|------------------------------------------------------------------|
| `results`  | array of ArticleSummary| Up to `limit` published articles, newest first.                  |
| `has_more` | boolean                | `true` iff at least one more published article exists after this page. |
| `limit`    | integer                | Echo of the effective `limit`.                                   |
| `offset`   | integer                | Echo of the effective `offset`.                                  |

`GET /articles` SHALL reject malformed pagination with `400 Bad Request` and a JSON body `{"error": "<message>", "param": "<offending param name>"}`:

- `limit` parses but is outside `[1, 100]` → `param: "limit"`
- `limit` does not parse as a non-negative integer → `param: "limit"`
- `offset` parses but is negative → `param: "offset"`
- `offset` does not parse as a non-negative integer → `param: "offset"`

#### Scenario: Published articles are listed newest first

- **WHEN** `GET /articles` is called and three articles are published
- **THEN** the response SHALL be `200` with `results` holding their `ArticleSummary` shapes ordered by `published_at` descending, plus the echoed `limit`/`offset` and a correct `has_more`

#### Scenario: Drafts never appear in the list

- **WHEN** the store holds two published articles and five drafts
- **THEN** `GET /articles` SHALL return only the two published articles; no draft SHALL be represented

#### Scenario: Empty list is a valid response

- **WHEN** no article is published
- **THEN** the response SHALL be `200` with `"results": []`, `"has_more": false`, and the echoed `limit`/`offset`

#### Scenario: Invalid limit returns 400 with named param

- **WHEN** `GET /articles?limit=0` or `GET /articles?limit=abc` is called
- **THEN** the response SHALL be `400` with `{"error": "<message>", "param": "limit"}`

### Requirement: Public single-article endpoint

`rbrain-chronicle` SHALL expose `GET /articles/{slug}`, returning the published article whose `slug` matches the path segment.

On a match, the response SHALL be `200 OK`, `Content-Type: application/json`, with the `Article` payload. When no published article has that slug — including the case where a draft exists with that slug — the response SHALL be `404 Not Found` with `{"error": "<message>"}`. A draft SHALL be indistinguishable from an absent article on the public surface.

#### Scenario: Published article is returned by slug

- **WHEN** `GET /articles/my-first-post` is called and a published article has slug `my-first-post`
- **THEN** the response SHALL be `200` with the `Article` payload

#### Scenario: Draft slug is a 404

- **WHEN** `GET /articles/{slug}` targets a slug that exists only as a draft
- **THEN** the response SHALL be `404` with `{"error": "<message>"}`; the response SHALL NOT reveal that a draft exists

#### Scenario: Unknown slug is a 404

- **WHEN** `GET /articles/{slug}` targets a slug no article has
- **THEN** the response SHALL be `404` with `{"error": "<message>"}`

### Requirement: No other public HTTP routes at v1

`rbrain-chronicle` SHALL expose exactly three **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `GET /articles`, and `GET /articles/{slug}` (defined here). Any additional public route — article comments, category indexes, RSS/Atom feeds, search — requires a MODIFIED delta on `chronicle-api` before the route ships.

Routes under the reserved prefix `/admin/*` are **operator/platform-internal** and SHALL NOT count toward this constraint. Editorial authoring (draft create/update, publish, delete) lives under `/admin/articles/*`; its shape and behavior are specified by `rbrain-chronicle`'s own authoring capability, not here, exactly as `scryfall-sync`'s `/admin/sync` lives in `rbrain-lexicon`. Per the `lexicon-api-admin-carveout` precedent and `gateway-api`, `/admin/*` PATHS SHALL NOT be reachable through `rbrain-gateway`: gateway rejects any external request whose path begins with `/admin/`. The gateway MAY expose its own authenticated, allowlist-gated editorial surface (`/editorial/*`, per `gateway-api`) that rewrites onto this internal admin surface — the trust decision then lives at the gateway boundary, and chronicle's admin routes remain unreachable by their own path.

#### Scenario: New public route goes through OpenSpec

- **WHEN** a contributor adds `GET /feed.xml` or `GET /categories` to chronicle
- **THEN** the change SHALL include a MODIFIED requirement on this spec before the route ships; CI on chronicle alone is not enough to make it part of the public surface

#### Scenario: Authoring routes are operator-internal, not public

- **WHEN** a contributor adds `POST /admin/articles` or `POST /admin/articles/{id}/publish` to chronicle
- **THEN** that route SHALL live under `/admin/*`, SHALL NOT count toward this public-route closure, and SHALL NOT be reachable through gateway by its own `/admin/*` path — only, where `gateway-api` declares it, through the gateway's authenticated `/editorial/*` rewrite

#### Scenario: /health does not need a chronicle-api requirement

- **WHEN** a contributor reads chronicle-api/spec.md looking for /health
- **THEN** they SHALL find it referenced here as out-of-scope-for-this-capability and authoritative in `repository-conventions`; this spec SHALL NOT restate the /health contract

