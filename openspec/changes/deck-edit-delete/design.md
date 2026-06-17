## Context

Deck CRUD is missing the U and D: forge has `POST`/`GET`, the gateway proxies them protected, the app lists/views. Edit and delete reuse the same `gateway → forge` + `X-User-Id` ownership machinery.

## Goals / Non-Goals

**Goals:** owner-scoped edit and delete completing deck CRUD.

**Non-Goals:** partial-field PATCH semantics distinct from PUT (kept simple — see Decision 1); deck sharing; revision history.

## Decisions

### Decision 1: `PUT /decks/{id}` is a forgiving partial update

The body is `{ name?, decklist? }`; at least one field is required (neither → `422`). When `decklist` is present, forge re-parses it (same parser) and replaces the four sections + `total_mainboard`; when `name` is present, it updates the name. This supports both "rename in the list" and "re-paste the list" without two separate endpoints. It is named `PUT` (the resource's mutable state is name+sections) but tolerates a single-field update — pragmatic over strict REST replacement.

### Decision 2: Owner scoping = 404, never 403

Edit/delete filter on `user_id` and return `404` for an id not owned by the caller — identical to `GET /decks/{id}`, leaking no existence of other users' decks.

### Decision 3: `DELETE` → 204

A successful delete returns `204 No Content` (no body); a missing/foreign id returns `404`. Idempotency is not promised (a second delete of the same id is `404`), which is acceptable for this UI.

## Risks / Trade-offs

- **PUT-as-partial** bends REST semantics slightly; documented so consumers know a single field is allowed. The alternative (separate PATCH) is more endpoints for no real gain at this scale.

## Migration

None — same table, additive routes.
