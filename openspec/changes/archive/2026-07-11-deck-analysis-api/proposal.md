# deck-analysis-api

## Why

Deck analysis exists everywhere except the UI. forge owns the analysis math (`POST /decks/analyze`, stateless, caller-supplied card facts); cortex owns the composition (its `analyze_deck` tool resolves facts via lexicon and calls forge) — but the only way a user reaches it is prose through `POST /chat`. The app's decks page shows a stored deck's cards and nothing else; surfacing mana curve, color distribution, and type breakdown next to the list is the natural next slice, and it needs a deterministic JSON endpoint, not an LLM conversation.

## What Changes

The composition point stays where `service-topology` and `forge-api` already put it — **cortex** ("forge SHALL NOT fetch card data itself … supplying facts is the caller's job (cortex, per service-topology)"). Cortex gains a deterministic public route that reuses its existing tool composition against a **stored** deck; the gateway proxies it. Zero new sync-graph edges: `gateway → cortex`, `cortex → forge`, and `cortex → lexicon` all exist.

- MODIFY `cortex-api`: ADD requirement "Deck analysis composition endpoint" — `GET /decks/{deck_id}/analysis`, `X-User-Id`-scoped, composing forge's stored deck + lexicon facts + forge analysis; MODIFY the route-closure clause (two → three public routes).
- MODIFY `gateway-api`: the protected-proxy requirement gains `GET /decks/{id}/analysis` → cortex (one deck route deliberately targets cortex, not forge — it is a composition, not storage); route-closure clause nineteen → twenty; CORS route enumeration updated.

Rejected alternatives:
- forge fetches facts itself (forge → lexicon edge): contradicts the explicit `forge-api` doctrine and adds a sync-graph edge for one feature.
- App-side composition through public routes: needs forge's analyze exposed publicly (forge-api MODIFY), fans one analysis view into 15-25 gateway roundtrips for fact resolution, and re-implements composition already owned by cortex.
- Chat-only status quo: no structured data for UI rendering; an LLM roundtrip for deterministic arithmetic.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `cortex-api`: new composition endpoint + closure clause.
- `gateway-api`: new proxied route + closure clause + CORS enumeration.

## Impact

- Sibling implementations follow in `rbrain-cortex` (endpoint), `rbrain-gateway` (route — the `/decks/*rest` wildcard becomes explicit per-route entries so `/decks/{id}/analysis` can target cortex), and `rbrain-app` (analysis panel on the decks page, consumed through the existing BFF catch-all — no app API change).
- `rbrain-forge` is untouched.
- `service-topology/sync-graph.yaml` is untouched.
