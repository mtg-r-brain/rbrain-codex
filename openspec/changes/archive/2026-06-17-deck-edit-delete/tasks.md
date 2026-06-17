## 1. Contract (rbrain-codex)

- [ ] 1.1 forge-api: ADD "Deck update and delete (user-scoped)"; MODIFY route closure 5 → 7.
- [ ] 1.2 gateway-api: MODIFY protected routes — add `PUT /decks/{id}`, `DELETE /decks/{id}`.
- [ ] 1.3 `openspec validate deck-edit-delete --strict` passes.

## 2. Archive

- [ ] 2.1 Push planning commit.
- [ ] 2.2 Archive + `git add -A openspec/`; promote canonical forge-api / gateway-api.
- [ ] 2.3 Push the archive commit.

## 3. Implementations (sibling changes)

- [ ] 3.1 `rbrain-forge` `deck-edit-delete`: `DeckStore.update`/`delete` (owner-scoped); `PUT`/`DELETE /decks/{id}` handlers (422 empty PUT, 404 cross-user, 204 delete); tests.
- [ ] 3.2 `rbrain-gateway` `deck-edit-delete`: add `PUT`/`DELETE` on `/decks/*rest` (protected); spec MODIFY; test.
- [ ] 3.3 `rbrain-app` `app-deck-edit-delete`: delete button + edit (rename / re-paste) on /decks; api helpers `updateDeck`/`deleteDeck`.
