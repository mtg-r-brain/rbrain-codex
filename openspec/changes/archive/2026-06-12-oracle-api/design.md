## Context

The oracle BC is scaffolded but empty: the baseline ships a `/health` endpoint and nothing else. Its mission per `bounded-contexts/catalog.yaml`: "answers Magic: The Gathering rules questions by retrieving and reasoning over the comprehensive rules and community sources." The platform's full Q&R loop will eventually be:

```
user → app → gateway → cortex → (lookup_rule tool) → oracle → reply
```

This change ships only the oracle side of the trailing link. The `cortex → oracle` edge is already declared in `service-topology/sync-graph.yaml` (purpose: "rules queries used as agent tools"). The cortex-side `lookup_rule` tool, the WotC sync pipeline, the embedding pipeline, and the semantic search endpoint are all deferred to follow-up changes.

The pattern mirrors `lexicon-api` and `cortex-api`: one capability per bounded context's public surface, with the closure clause enforced by `repository-conventions` "<context>-api capabilities include a route-closure clause" (ratified earlier today) and audited by `scripts/validate-api-closure.sh` (also ratified today).

## Goals / Non-Goals

**Goals:**

- Anchor `rbrain-oracle`'s external HTTP contract in codex so future gateway/cortex/SDK work has a single source of truth.
- Specify `GET /rules/{number}` precisely: opaque path parameter, 200 / 404 shapes, three-field payload.
- Establish the closure clause so `/rules` + `/health` are the only public routes at v1; adding `POST /rules/semantic-search` or any other endpoint requires a MODIFIED.
- Stay descriptive — the oracle implementation is small enough to ship in the companion change in one sitting.

**Non-Goals:**

- Semantic search (`POST /rules/semantic-search` or similar). Worth doing once the rules are indexed via pgvector; out of scope here.
- WotC ingestion pipeline. Oracle's sync from `media.wizards.com` is the companion to lexicon's Scryfall sync; ship after MVP storage works.
- Cortex `lookup_rule` tool. Cortex doesn't need it on day one; the contract is consumable by the gateway slice when it lands.
- Ruling annotations, glossary entries, format-specific notes. The slice ships *rules* only — `glossary`, `rulings`, `comprehensive-rules-sections` etc. are deferred.
- Streaming responses. Same non-goal as `lexicon-api` and `cortex-api`.
- Multi-version rule history (rule 100.1 in M21 vs M22). One canonical version per build; versioning belongs to a future capability.

## Decisions

### Decision 1: Path parameter is opaque to the routing layer

**Choice:** `{number}` is a free-form string passed verbatim to the handler — no normalisation, no validation in routing. Lookup falls through to 404 when the number is unknown. The expected format is the standard MTG rule numbering (`100`, `100.1`, `702.21a`) but the spec doesn't enforce it at the routing level.

**Rationale:** Same as `lexicon-api`'s `{scryfall_id}` opaqueness — keeps the routing layer minimal and lets the handler own the matching logic. MTG rule numbers have a few variants (top-level `100`, sub-section `100.1`, sub-rule `100.1a`); attempting to validate at the routing layer would either be wrong or over-strict.

### Decision 2: Response shape is three fields — `number`, `text`, `source`

**Choice:**

```json
{
  "number": "100.1",
  "text": "These Magic rules apply to any Magic game with two or more players, including two-player games and multiplayer games.",
  "source": "Comprehensive Rules"
}
```

`source` distinguishes the canonical comprehensive rules from future additions (tournament rules, judge documents, etc.). At v1 the only allowed value is `"Comprehensive Rules"`.

**Rationale:** Three reasons:

1. **Symmetry with `lexicon-api`.** Six fields on Card, three on Rule. Each capability picks the smallest shape that conveys its essence.
2. **`source` is forward-compatible.** When tournament rules ship in a future slice, the enum widens; consumers that already switch on `source` get the new value for free.
3. **No timestamp at v1.** The `updated_at` on the row is operational metadata, not part of the contract.

**Alternatives considered:**

- **Just `number` + `text`**: rejected. `source` is cheap and forward-compatible.
- **Full structured payload (rule + parent + children + cross-refs)**: rejected. Premature; slice 1 is exact-lookup only.
- **`text` as Markdown**: rejected. The Comprehensive Rules ship as plain text; we honor that.

### Decision 3: 404 carries the same `{error, number}` shape as lexicon's

**Choice:**

```json
{
  "error": "rule not found",
  "number": "<the raw path parameter>"
}
```

**Rationale:** Mirrors `lexicon-api`'s 404 shape, so consumers writing client adapters can reuse the same error-handling pattern across BCs. The literal `"rule not found"` mirrors `"card not found"`.

### Decision 4: Closure clause is two routes at v1 — `/health` and `/rules/{number}`

**Choice:** Same form as lexicon's and cortex's closure clauses: "SHALL expose exactly two **public** HTTP routes at v1: `GET /health` (defined by `repository-conventions`), `GET /rules/{number}` (defined here)." Adding `POST /rules/semantic-search` or any other endpoint requires a MODIFIED.

**Rationale:** Pattern matches lexicon-api / cortex-api exactly; `scripts/validate-api-closure.sh` already enforces the canonical wording.

## Risks / Trade-offs

- **[Risk] WotC distributes the Comprehensive Rules as a `.txt` file whose format changes between updates** → Not a v1 concern; the implementation companion stores a single seed rule. The sync pipeline (slice 2 or 3) handles WotC's format quirks.

- **[Trade-off] No semantic search at v1** → Accepted. Cortex doesn't have a tool that needs it yet. Adding `POST /rules/semantic-search` (or `GET /rules?q=...`) when the embeddings ship is a MODIFIED on `oracle-api`.

- **[Risk] `{number}` opaqueness invites the wrong format from a careless caller** → Mitigation: 404 path is well-defined; the consumer's recourse is to read the error and retry with the correct format.

- **[Trade-off] `source` field at v1 has only one possible value** → Accepted. Future flexibility outweighs the one-line-of-noise cost.

## Open Questions

None. The slice is bounded by today's scaffolded oracle and the planned tracer-bullet implementation.
