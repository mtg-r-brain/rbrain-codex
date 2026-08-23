## Why

The sixteen-format whitelist (ADR 0003) lives in five code constants and five spec prose passages
across five repositories, with nothing checking that they agree. The pair that matters is
`rbrain-lexicon` (publishes per-format legalities on `rbrain.lexicon.card-legality-updated`) and
`rbrain-forge` (consumes them into its `card_legality` read-model and validates deck formats): a
format added to one side and not the other desynchronizes silently — lexicon emits a key forge never
reads, or forge accepts a format lexicon never populates, and no test, validator, or runtime error
says so. This is the last known item on the platform that can break real behaviour without a signal.

The whitelist has already grown once (7 → 16, ADR 0003), and Scryfall adds formats regularly; the
next growth will reproduce the drift window unless the list gets a single enforced source.

## What Changes

- New `format-catalog` capability: `openspec/specs/format-catalog/formats.yaml` becomes the single
  machine-readable, platform-level source of the whitelist — same pattern as
  `bounded-contexts/catalog.yaml` and `service-topology/sync-graph.yaml`.
- New validator `scripts/validate-formats.sh`, two modes: self mode (codex CI) checks the catalog's
  shape and that `forge-api`'s prose enumeration equals it; sibling mode (lexicon and forge CI, run
  from their existing `.codex` checkout, same wiring as `validate-repo.sh`) checks the repo's
  `FORMATS` constant against the catalog as a set.
- `forge-api` MODIFIED: the accepted-identifiers sentence now names the catalog as the set's source
  (instead of deriving it from lexicon's published whitelist), and the requirement prose drops its
  hard-coded "sixteen" count words so a future catalog change does not leave stale numerals behind.
- **BREAKING**: none. No wire shape, storage shape, route, or accepted value changes anywhere; the
  sixteen formats stay exactly as ratified by ADR 0003. This is provenance plus enforcement.

## Capabilities

### Added Capabilities

- `format-catalog`: the platform format whitelist as a machine-readable catalog, its shape rules,
  and the CI obligations on codex itself and on the two consuming repositories.

### Modified Capabilities

- `forge-api`: the accepted `format` identifiers' set is now sourced from the format catalog;
  count-free prose; identifiers unchanged.

## Impact

- `rbrain-codex`: new `formats.yaml` + `validate-formats.sh` + one CI step; `forge-api/spec.md`
  reworded.
- `rbrain-lexicon`, `rbrain-forge`: one CI step each (`bash .codex/scripts/validate-formats.sh .`
  after the existing validate-repo step) and a source-of-truth pointer in the `FORMATS` doc
  comment. Chore commits referencing this change — no OpenSpec change of their own, their
  contracts and constants are untouched (precedent: rbrain-deploy's NATS_URL wiring per
  `deployment-stack-forge-nats`).
- `rbrain-cortex`, `rbrain-app`: none now. Their enums gate input and fail loud (422 round-trip),
  so drift there is a UX gap, not silent corruption; wiring them into sibling mode is a cheap
  follow-up once wanted.
