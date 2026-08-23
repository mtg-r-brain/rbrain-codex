# Design — platform-format-catalog

## Decision 1: CI-checked equality, not code generation

The catalog enforces; it does not generate. Lexicon and forge keep their language-native `FORMATS`
constants, and a validator compares each constant to `formats.yaml` as a set in CI.

Rejected alternatives:

- **Codegen from YAML** (build step emitting a Rust module per repo): adds a build-time dependency
  on a spec repository to two autonomous services, plus generator tooling to maintain, for a
  sixteen-line list that changes roughly once a quarter at most. The failure mode codegen prevents
  (constant drift) is fully covered by the CI check at a fraction of the machinery.
- **Fetching the catalog at runtime**: couples service startup to the availability of a Git host or
  a config volume, for data that is compile-time by nature (forge's Rust array length is part of the
  type). Worst trade on the board.

## Decision 2: prose enumerations stay, and the codex one is validator-covered

`forge-api`'s human-readable enumeration remains — a contract a human reads should name its values.
The duplication risk is retired differently per surface:

- The codex enumeration is cross-checked against the catalog by `validate-formats.sh` self mode,
  anchored on the sentence `The **accepted `format` identifiers** are exactly: ...`. The anchor is
  part of the contract's own wording; the validator dies loudly if the sentence disappears, so the
  check cannot rot silently.
- Hard-coded count words ("sixteen") are removed from the requirement prose everywhere except the
  enumeration itself, so a future catalog change cannot leave stale numerals behind.
- Repo-local spec prose that also enumerates the list (`lexicon-events`, `forge-deck-persistence`,
  `cortex-bootstrap`, `app-decks`) is NOT validator-covered by this change: those repos' canonical
  specs only change through their own OpenSpec cycles, and a growth of the catalog already forces
  such cycles (the constants gate CI). Their wording gets realigned to point at the catalog on
  their next touch.

## Decision 3: scope is lexicon + forge

They are the producer/consumer pair whose drift corrupts data silently (a legality key emitted but
never read, or read but never emitted). Cortex's tool enums and app's `<select>` gate input and
fail loud — an unknown format 422s at forge — so drift there is a visible UX gap. Sibling mode is
written so adding a context is one `case` arm; cortex/app wiring is a follow-up, not scope creep.

## Decision 4: script mechanics

- The catalog path resolves relative to the script's own location (`dirname $0/..`), so the same
  invocation works from a sibling checkout (`../rbrain-codex`) and from the CI checkout path
  (`.codex`). `FORMATS_FILE` overrides for tests.
- Sibling mode reads the repo's `OWNERSHIP.yaml` `context` to pick the extraction target — the same
  identity mechanism `validate-repo.sh` already trusts. A context with no registered format surface
  dies loudly rather than no-oping, so mis-wiring is visible.
- Rust extraction: the lines from `pub const FORMATS` to the first `];`, then the quoted lowercase
  tokens. Both constants are one-string-per-line rustfmt output; `cargo fmt --check` in those repos
  keeps them that way. The array's declared length (`[&str; 16]`) is compiler-enforced against the
  entries, so the validator does not re-check counts.
- No `mapfile`, no `declare -A`: unlike the ubuntu-only validators, this one also runs on
  contributor macOS (bash 3.2) via the documented local gate sequence.

## Ordering note

Self mode greps the CANONICAL `forge-api/spec.md`, which gains the new anchor sentence only at
sync. Within this change, the validator therefore only passes locally after `openspec archive` has
promoted the deltas — run the full validator suite at the sync step, not at the feat step. CI only
ever sees the pushed head, so this is invisible remotely.
