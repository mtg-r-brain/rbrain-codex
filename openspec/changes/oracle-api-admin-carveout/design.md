## Context

`oracle-api` v1 explicitly forbade `/admin/*` until a real consumer demanded it. The smoke-tested cortex agent loop now wants oracle to ship actual Comprehensive Rules content, which requires a sync pipeline — and a sync pipeline needs an operator trigger.

The precedent is `lexicon-api-admin-carveout`, archived 2026-06-11: it carved `/admin/*` out of lexicon's closure clause so `scryfall-sync` could ship `POST /admin/sync`. The text we're inserting into `oracle-api` is the same text, retargeted to oracle. Zero new design — pure pattern propagation.

## Goals / Non-Goals

**Goals:**

- Allow `/admin/*` routes on oracle without bypassing the closure clause for public routes.
- State the gateway-rejection invariant so external traffic to `/admin/*` is forbidden once `rbrain-gateway` ships.
- Make the change cheap to author (literally a copy of the lexicon carve-out's structure).

**Non-Goals:**

- Specifying any specific `/admin/*` endpoint. `POST /admin/sync` and its shape live in the consuming oracle spec.
- Authentication on `/admin/*`. The carve-out is positioning-only at v1 (internal-only by network topology); auth ships when gateway lands.
- Rate-limiting or audit logs on `/admin/*`. Same — operational concerns deferred.

## Decisions

### Decision 1: Mirror the lexicon-api carve-out wording verbatim

**Choice:** The MODIFIED body inserts two paragraphs verbatim from `lexicon-api`'s carve-out, swapping `lexicon` → `oracle` and `scryfall-sync` → `comprehensive-rules-sync` as the example consuming capability.

**Rationale:** Repository-conventions' "<context>-api capabilities include a route-closure clause" requirement (archived earlier today) treats the carve-out as a known pattern. Copying it verbatim guarantees:

1. Reviewers recognize the pattern instantly.
2. `validate-api-closure.sh` continues to match the canonical closure phrasing.
3. Future siblings can cargo-cult the same MODIFIED template when they need admin endpoints.

### Decision 2: Add a "Gateway rejects external admin traffic" scenario

**Choice:** Same scenario shape as lexicon's: a `WHEN/THEN` pair stating that gateway (once shipped) rejects any external path matching `^/admin/`.

**Rationale:** Specifies the long-term posture before gateway exists, so when gateway's spec lands, it has a clear contract to honor. Costs nothing and prevents a forgotten requirement.

## Risks / Trade-offs

- **[Risk] We carve `/admin/*` out and the next slice never ships** → Accepted. The cost of a dormant carve-out is zero; the cost of forcing two changes (carve-out + sync) into one MODIFIED is sequencing pain.

- **[Trade-off] Same shape as lexicon's carve-out means cargo-culting** → Accepted, intentional. Pattern reuse is the goal.

## Open Questions

None.
