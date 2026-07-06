## 1. Contract (rbrain-codex)

- [ ] 1.1 forge-api: ADD deck analysis endpoint (facts-supplied model, six metrics, graceful unresolved); MODIFY closure seven → eight (analyze joins the in-cluster set).
- [ ] 1.2 `openspec validate forge-deck-analysis --strict` passes.

## 2. Archive

- [ ] 2.1 Push planning commit; archive; push archive commit.

## 3. Implementations (sibling changes)

- [ ] 3.1 `rbrain-forge` `deck-analysis`: analysis module (CMC from mana_cost incl. X/hybrid, curve buckets 0-6/7+, symbol counts, primary-type classification), POST /decks/analyze handler (422 paths), unit tests on the domain math.
- [ ] 3.2 `rbrain-cortex` `analyze-deck-tool`: `analyze_deck(decklist)` tool — parse via forge, resolve unique mainboard names via lexicon search (exact case-insensitive match on results), assemble card_facts, call analyze, observation = wire payload; six-tool SYSTEM_PROMPT.
- [ ] 3.3 Runtime validation: chat-driven "analyze this deck" e2e on the stack (curve/colors/types in the reply; unresolved names surfaced).
