## Why

Deck analysis is the second half of the depth pivot (queue item 5a) and half of forge's own catalog mandate — "parses, stores, and **analyzes** Magic decks" — yet nothing implements it. The topology forbids the obvious shortcut: forge has no `forge → lexicon` edge (June audit note: "would be cortex-mediated"), and mana curves need per-card facts (mana cost, type line) that only lexicon holds.

The faithful split: **cortex orchestrates, forge computes**. Cortex resolves card facts through its existing `cortex → lexicon` edge and hands them to a new stateless forge endpoint that owns the domain math — mirroring how `POST /decks/parse` already works (in-cluster, not gateway-exposed).

## What Changes

- MODIFY `forge-api`:
  - ADD "Deck analysis endpoint" — `POST /decks/analyze`: body carries a `decklist` (string, required) and `card_facts` (array of `{name, mana_cost, type_line}`, required — the caller's lexicon lookups); forge parses the decklist and computes `mana_curve` (CMC histogram, `7+` bucket), `average_cmc` (non-land mainboard), `color_distribution` (mana-symbol counts W/U/B/R/G/C), `type_breakdown` (primary card types), `total_mainboard`, and `unresolved` (mainboard names with no matching fact — analysis proceeds without them). `422` on missing/blank `decklist` or missing `card_facts`.
  - MODIFY "No other public HTTP routes at v1": seven → **eight** (the analyze route joins `/decks/parse` in the in-cluster, non-gateway set).
- No `gateway-api` change: like `/decks/parse`, `/decks/analyze` is not publicly proxied; it serves the `cortex → forge` edge.

## Capabilities

### Modified Capabilities

- `forge-api`: analysis endpoint added; closure eight.

## Impact

- Implementations land as sibling changes: `rbrain-forge` (analysis module + endpoint) and `rbrain-cortex` (`analyze_deck` tool: parse → resolve unique names via lexicon → analyze; six-tool prompt).
- v1 approximation, documented: colors derive from mana-cost symbols (not color identity — lands and off-cost abilities are invisible to it); format legality stays out (needs banlist data nobody owns yet).
