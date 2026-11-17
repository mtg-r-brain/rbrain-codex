# Tasks — lexicon-printing-ordering

Contract delta in this repo; the ordering lands in `rbrain-lexicon`; the opt-in
`printing=first` consumption is the `rbrain-app` chat/deck hover slice (its own
change set over there).

## 1. Ship the delta

- [x] Write the `lexicon-api` delta: MODIFIED "rbrain-lexicon exposes GET /cards search" (`printing` param, earliest-plain policy, `any` default preserving legacy order) and MODIFIED "GET /cards validates query parameters" (400 for unknown/mis-paired `printing`)
- [x] `openspec validate lexicon-printing-ordering --strict`

## 2. Lexicon implementation slice (`rbrain-lexicon`)

- [ ] Handler: parse/validate `printing` (`any` | `first`; 400 `{error, param:"printing"}` on unknown value or with `q`)
- [ ] Postgres store: policy ORDER BY over `raw_scryfall` (`lang='en'`, `set_type` exclusion list, empty `frame_effects`, `released_at` asc nulls last, `scryfall_id`) for `printing=first`; unchanged SQL for `any`
- [ ] In-memory store: same ordering parity (it is the unit-test fixture and must not diverge)
- [ ] Tests: policy selects the oldest plain printing over promo/showcase/foreign rivals; `any` byte-identical to today; unknown value and `q`+`printing` → 400 with `param: "printing"`; result set never filtered
- [ ] `cargo test` + repo lint gates green

## 3. Live verification

- [ ] Rebuild `rbrain-lexicon`, `GET /cards?name=Lightning Bolt&printing=first` through the gateway answers with the Alpha printing first; without the param, the legacy order is preserved

## 4. Land

- [ ] `🔄 sync(lexicon-printing-ordering)` — promote both MODIFIED requirements to the canonical `lexicon-api` spec
- [ ] `📦 archive(lexicon-printing-ordering)`
