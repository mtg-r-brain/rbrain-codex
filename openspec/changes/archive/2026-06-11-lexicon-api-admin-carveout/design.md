## Context

The `lexicon-api` capability in codex was written when lexicon shipped only `/health` and `/cards/{scryfall_id}`. Its "No other HTTP routes at v1" requirement intentionally forbade unannounced expansion. Slice 3 needs a `POST /admin/sync` endpoint to trigger Scryfall ingestion — clearly an operator concern, not a cross-context API.

Stakeholders: lexicon (immediate impact), gateway (will eventually enforce the carve-out at ingress), and any future sibling that wants an admin endpoint (gets a precedent here).

## Goals / Non-Goals

**Goals:**

- Carve out a stable namespace (`/admin/*`) for platform-internal endpoints without breaking the rigor of the cross-context contract.
- Make the public-vs-admin distinction explicit and enforceable.
- Unblock `scryfall-sync` without forcing it through a contract battle.

**Non-Goals:**

- Specifying any individual `/admin/*` endpoint. Each one lives in the sibling's own spec.
- Adding auth on admin endpoints in this change. That belongs in a future change once `rbrain-identity` and `rbrain-gateway` ship.
- Promoting admin endpoints to part of the public contract.

## Decisions

### D1. `/admin/*` is a reserved prefix on every sibling

The carve-out is documented as a platform pattern: any sibling MAY introduce operator endpoints under `/admin/*` without amending its `<context>-api` capability, provided the endpoints are NOT exposed via `rbrain-gateway`.

**Rationale:** Per-sibling carve-outs would fragment the convention. A single rule applied platform-wide is easier to remember and harder to violate accidentally.

**Alternatives considered:**

- **`/internal/*`** — rejected: less self-explanatory than `/admin/*`. "Internal" can mean "internal to the bounded context" which conflicts with our DDD vocabulary.
- **Per-context prefix** (e.g. `/lexicon-admin/sync`) — rejected: redundant when the host is already lexicon's.
- **Header-based filtering** (e.g. `X-Internal: true`) — rejected: harder to audit, harder to deny at the gateway.

### D2. Gateway enforces the carve-out; lexicon doesn't lock itself

The contract says admin endpoints MUST NOT reach lexicon from outside the cluster. That enforcement happens at `rbrain-gateway` once it ships. Lexicon does NOT add IP-based filtering, network namespace tricks, or auth at v1. It listens on `0.0.0.0:8080` per the existing template and trusts that only in-cluster callers reach it.

**Rationale:** Defense in depth is nice but premature here. The single point of enforcement (gateway) is simpler to audit and to amend. Adding lexicon-side filtering would duplicate logic across every sibling.

**Alternatives considered:**

- **Lexicon listens on a separate port for /admin/*** — rejected: doubles the operational surface for no gain at v1.
- **Auth middleware on /admin/*** — accepted as a future change once `rbrain-identity` ships and we have JWT verification utilities.

### D3. The MODIFIED requirement text is small but the scope shift is explicit

The amended requirement says: "**public** HTTP routes". A second scenario explicitly exempts `/admin/*` from the constraint. Reading the spec, a contributor sees both the old constraint and the new exemption.

**Rationale:** Surface-level keyword changes (`public`) are easy to miss; an explicit scenario makes the intent unambiguous.

## Risks / Trade-offs

- **An admin endpoint accidentally exposed via gateway.** → Mitigation: the gateway-side routing rules (when shipped) MUST reject `/admin/*`. The convention is documented here; the enforcement lands in gateway. Until then, lexicon is internal-only by topology, so the risk is zero.
- **Operators expect a stable admin API and discover none exists in spec.** → Mitigation: each `/admin/*` endpoint lives in the sibling's own capability spec, which operators can read.
- **Convention spillover**: other siblings may abuse the carve-out to ship features bypassing OpenSpec. → Mitigation: code review and CI catch this — every new HTTP route ships with a justification.

## Migration Plan

No code change. The MODIFIED delta is a documentation amendment to the live `lexicon-api` spec. The slice 3 change in lexicon ships on top of this amendment.

## Open Questions

None at v1. The auth + gateway enforcement story will get its own OpenSpec change when `rbrain-gateway` ships.
