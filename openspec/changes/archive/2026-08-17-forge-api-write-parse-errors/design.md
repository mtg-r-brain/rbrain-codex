## Context

`errors` is unlike every other field in the stored deck payload, and that difference drives the whole
design. The other eleven describe **the deck**: ask for them again tomorrow and they are still true.
`errors` describes **the text submitted in one request** — which lines of it forge could not read.
Nothing about the stored deck records that text, and after one row-level edit through the app's
editor it no longer exists in any form.

So the field cannot be uniform across the routes the way `format` or `status` are. `GET /decks/{id}`
has, structurally, nothing to report: no parse happened.

Two facts from the previous slices bound the choices:

- **`forge-api` closes the payload field set** (T0, 2026-08-17). Adding `errors` therefore requires
  this delta, and the field must be described for *every* route that returns the payload — including
  the ones where it is always empty. Silence about a route would be exactly the drift T0 cleaned up.
- **Consumers already tolerate it** (`forge-payload-tolerance`, cortex, 2026-08-17). `StoredDeck`
  declares `errors` with an empty-list default, so neither ordering of the forge and cortex rollouts
  breaks anything. This removes the lockstep pressure that shaped the two previous waves and is why
  this delta can be plain rather than defensive.

## Goals / Non-Goals

**Goals:**
- A user who saves or edits a deck through the app can be told which lines were dropped.
- The write path reports it; no new route, no new request field, no change to what saves successfully.
- The read-side emptiness is stated in the contract, not left for a consumer to discover.

**Non-Goals:**
- No persistence of the errors (Decision 2), hence no migration and no `deck_versions` column.
- No change to `POST /decks/analyze`, which has the same silence and no complaint against it.
- No hard rejection of a decklist with unreadable lines (Decision 3).
- No error-count field, no truncation cap. A pasted decklist is bounded by what a human pastes; a cap
  would be a guess at a problem nobody has.

## Decisions

**1. `errors` joins the existing payload as a twelfth-plus-one field, rather than being returned in a
wrapper.**
The alternative — `{ deck: {...}, errors: [...] }` on the write routes only — is honest about the
field's transactional nature and would sidestep Decision 2's ambiguity entirely. Rejected on cost:
every existing consumer of `POST`/`PUT /decks` breaks at once, including the three `build_deck` /
`revert_deck_draft` / `finalize_deck` tools shipped 2026-08-16, all of which read the deck fields at
the top level. That is a real break traded for a modelling nicety. It also splits the payload shape by
route, so a consumer could no longer use one type for all five persistence responses — `StoredDeck` in
cortex, and forge's own `StoredDeck` struct.

This is the third use of the same additive pattern in this contract, after `format`/`format_violations`
and `status`/`version`. Consistency with the two precedents is worth more here than modelling purity,
and the precedents were themselves accepted on the same grounds.

**2. The field is populated per-request and never persisted.**
Populated on `POST /decks` always (a create always parses), and on `PUT /decks/{id}` when the request
carried a `decklist`. Empty on `GET /decks/{id}`, on `GET /decks/{id}?version=N`, and on a
`PUT /decks/{id}` that changed only `name`, `format` or `status`.
   - *Alternative considered*: persist the errors alongside the deck, in a column, so every route
     returns the same thing. Rejected as semantically false — the stored errors would describe a
     decklist text that the next row-level edit replaces, so a deck could report "line 7 unreadable"
     about text that no longer exists. Worse than reporting nothing, because it looks authoritative.
   - **The resulting ambiguity, stated rather than hidden**: on a read, `errors: []` means "this
     response did not parse anything", which is indistinguishable from "the last parse found nothing
     wrong". The delta says so explicitly. A consumer wanting to know whether a deck's *current*
     content parses cleanly must submit it — which is what the write routes are for. Making that
     legible in the contract is the cost of Decision 2, and it is smaller than the cost of a stored
     field that lies.
   - *Why the `name`-only `PUT` is empty rather than absent*: an always-present key with a stable type
     is easier to consume than one that appears and disappears, and it matches how
     `format_violations` already behaves when no format is set.

**3. Unreadable lines remain non-fatal.**
`POST`/`PUT` still succeed. This is not a new stance: `forge-deck-parsing` states that parsing never
fails the request, and `POST /decks/analyze` already returns an `unresolved` list rather than refusing
to analyze. A deck saved with a dropped line plus a report of the drop is strictly better than a
rejected save, because the user keeps the 59 cards that did parse and can fix the one line.
   - *Alternative considered*: `422` when any line fails, making the write all-or-nothing. Rejected —
     it changes the behaviour of an already-shipped route for every existing caller, including a
     `build_deck` call whose LLM-generated list has one bad line, which would lose the whole draft
     instead of 1 card. It also contradicts the parser's documented contract.

**4. `GET /decks` summaries do not gain the field.**
Summaries carry four fields and describe stored decks, never a submitted text. Adding an always-empty
`errors` there would be noise. T0's payload table already separates the summary shape from the full
payload, so this needs no special pleading.

## Risks / Trade-offs

- **[Trade-off] A field whose emptiness carries two meanings** (Decision 2). → Mitigated by stating it
  in the contract, and by the read/write asymmetry being inherent to the field rather than an artefact
  of this design: no design can report parse errors about a text that was never submitted.
- **[Risk] A consumer may read `errors` on a write response as "the deck is broken" and refuse to
  proceed.** The field means "these lines were dropped", not "the save failed". → Mitigated by
  Decision 3 being stated in the requirement text next to the field, and by the scenarios asserting
  the `201`/`200` explicitly.
- **[Trade-off] `rbrain-app`'s client-side grammar duplicate becomes redundant** once this lands, but
  removing it is a separate slice. Until then, the app blocks submission before forge ever sees the
  bad line, so this field will read as always-empty from that path. → Accepted and sequenced: the app
  slice is what makes this field observable end to end. Flagged so the field is not mistaken for
  broken in the interim.

## Open Questions

- Should `POST /decks/analyze` gain the same field? It parses a decklist and discards the same
  information, so the argument is identical. Deliberately out of scope: no caller has asked, and the
  analyze route's consumers (`analyze_deck`, the composition endpoint) already surface `unresolved`,
  which covers the adjacent "card not in the catalogue" case that users actually hit.
