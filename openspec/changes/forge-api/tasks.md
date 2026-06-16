## 1. Contract (rbrain-codex)

- [ ] 1.1 ADD `forge-api` capability: "Deck-list parse endpoint" (`POST /decks/parse` shape) + "No other public HTTP routes at v1".
- [ ] 1.2 `openspec validate forge-api --strict` passes.

## 2. Archive

- [ ] 2.1 Push planning commit.
- [ ] 2.2 Archive + `git add -A openspec/`; promote canonical `forge-api`.
- [ ] 2.3 Push the archive commit.

## 3. Implementation (sibling — rbrain-forge change `forge-deck-parsing`)

- [ ] 3.1 PORT env handling (default 8080); restructure to lib.rs + main.rs.
- [ ] 3.2 Deck parser module + `POST /decks/parse` handler matching this contract.
- [ ] 3.3 Tests + gates; forge's own `forge-deck-parsing` capability for the parse semantics.
