# ADR 0003 — Format whitelist grows to 16; legality storage/wire shape moves to a JSONB map

- **Status**: Accepted (2026-07-12)
- **Deciders**: Hoani Cross (owner), via strategic-fork review
- **Tracked as**: follow-up to ADR 0002 (forge-format-legality-via-nats)

## Context

ADR 0002's implementation (`lexicon-card-legalities`, `forge-format-legality`) whitelisted 7 formats — `standard`, `pioneer`, `modern`, `legacy`, `vintage`, `commander`, `pauper` — matching the platform vision doc's original list. Both the NATS wire contract (`rbrain.lexicon.card-legality-updated`) and `forge`'s storage (`forge.card_legality`) represent this as **one fixed field/column per format**, with the `lexicon-events` spec explicitly treating the field count as strict ("extra fields forbidden... requires an OpenSpec change").

The user requested the whitelist grow to cover the formats tracked by mtgtop8.com (verified via two live fetches: `duel`, `historic`, `alchemy`, `explorer`, `premodern` confirmed present; `historicbrawl`, `standardbrawl`, `timeless`, `future` NOT found in mtgtop8's navigation) plus, explicitly, those four unverified formats anyway (user's judgment call, honored). Net: **16 formats**, more than double the original count.

Scryfall's `legalities` object actually carries 23 possible keys and has grown over time (Alchemy, Standard Brawl, Timeless are all relatively recent additions). A fixed-field design was defensible at 7 formats; at 16 (with more plausible in the future) it means: a Postgres migration, a Rust struct field, and a strict wire-contract bump *per format*, every time the whitelist grows — the exact friction this expansion request just produced at 2x the original scope.

## Decision

Both the wire contract and the storage schema move from **N fixed fields** to **one JSON map field**, keyed by format name:

1. `rbrain.lexicon.card-legality-updated` becomes `{scryfall_id, oracle_id, name, legalities: {<format>: <legality>, ...}}` — a 4-field envelope instead of a 9-field (soon 18-field) flat structure. The `legalities` map SHALL contain exactly the whitelisted formats (still an explicit whitelist, still validated and fail-safe-defaulted per key at parse time) — this is a **representation change, not a scope change**: unrecognized/missing formats still default to `not_legal` with a warning, exactly as today.
2. `forge.card_legality` replaces its N `text` columns with one `legalities jsonb` column. This is consistent with — not a departure from — existing convention: `forge.decks.mainboard/sideboard/commander/maybeboard` are already `jsonb`, not one-column-per-card-slot.
3. The 16-format whitelist becomes a single shared constant per language (Rust: `legality_store::FORMATS`; Python: the tool's `args_schema` enum; TypeScript: `DECK_FORMATS`) — unchanged in kind from today, just longer.
4. Adding format #17 in the future is a whitelist-constant edit + a data backfill, **not** a migration and **not** a wire-contract field addition.

## Consequences

**Positive**: growing the whitelist again (Scryfall adds formats regularly) no longer requires a schema migration or a breaking wire-contract change in `lexicon`/`forge`; matches `forge.decks`'s own existing JSONB convention, so no new storage pattern enters the codebase; `cortex`'s and `app`'s whitelist constants are the only "flat list" surfaces left, and those were always going to need updating per format regardless of storage shape (they're UI/tool-schema enums, not wire/storage).

**Negative / cost**: this is a breaking change to the already-shipped `card-legality-updated` event shape and `forge.card_legality` table — every consumer (today: only `forge`) and every direct SQL/psql habit built during this session's live verification needs to adjust; `legality_for(format)` becomes a JSON key lookup instead of a match arm (marginally slower, immaterial at this scale); the "extra fields forbidden" strictness that guarded the flat-field design is replaced by "extra *keys in the map* forbidden," a slightly different validation shape to implement and test.

**Migration**: `lexicon` and `forge` both re-ship this as MODIFIED deltas against their already-archived capabilities (`lexicon-events`, `forge-format-legality`) — same capabilities, revised shape, not new capabilities. No data to migrate forward (this session's only stored legality rows were test fixtures, already cleaned up).

## Alternatives considered

- **Keep fixed fields, just add 9 more**: rejected — the friction that triggered this ADR (widening the whitelist requires touching 4 repos' schemas/contracts) would recur at the same cost on format #17, and Scryfall's format list is not static.
- **Fixed fields for a "core" subset + a JSONB overflow map for the rest**: rejected as needless complexity — two lookup paths for what is conceptually one kind of fact (a format's legality) is harder to reason about than one map, for no real benefit at this data volume (legalities per card is at most ~25 short strings).
