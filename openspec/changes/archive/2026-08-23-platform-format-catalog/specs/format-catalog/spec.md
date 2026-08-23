## ADDED Requirements

### Requirement: Single machine-readable source for the platform format whitelist

The platform's format whitelist SHALL be defined in exactly one machine-readable source: `openspec/specs/format-catalog/formats.yaml` in `rbrain-codex`. The file SHALL carry a top-level `formats` list of unique identifiers, each matching `^[a-z][a-z0-9]*$`. The whitelist is exactly the sixteen formats ratified by ADR 0003: `standard`, `pioneer`, `modern`, `legacy`, `vintage`, `commander`, `pauper`, `duel`, `historic`, `alchemy`, `explorer`, `premodern`, `historicbrawl`, `standardbrawl`, `timeless`, `future`.

Changing the set SHALL be an OpenSpec change against this capability. Every other surface that names the whitelist — per-repo language constants, contract prose, tool and UI enums — follows the catalog, never the other way around.

#### Scenario: A seventeenth format is added

- **WHEN** a new format enters the platform whitelist
- **THEN** `formats.yaml` gains the identifier through an OpenSpec change against `format-catalog`, and the consuming surfaces are updated in the same coordinated cycle — a whitelist edit plus data backfill, not a schema migration or a wire-contract field addition (ADR 0003)

#### Scenario: A malformed identifier is rejected

- **WHEN** `formats.yaml` carries a duplicate entry or an identifier that does not match `^[a-z][a-z0-9]*$`
- **THEN** `bash scripts/validate-formats.sh` fails naming the offending identifier, and codex CI goes red

### Requirement: Consuming repositories are CI-checked against the catalog

`rbrain-lexicon` (`src/legality.rs`, `FORMATS`) and `rbrain-forge` (`src/legality_store.rs`, `FORMATS`) SHALL each carry a language-native whitelist constant whose set of values equals the catalog exactly. Each of the two repositories' CI SHALL run `scripts/validate-formats.sh <repo-path>` from its `rbrain-codex` checkout, and the script SHALL fail naming the missing and extra identifiers when the constant and the catalog diverge.

The constants stay language-native by design: the catalog is enforcement, not code generation, and neither repository takes a build-time or runtime dependency on `rbrain-codex`.

#### Scenario: A format lands on one side only

- **WHEN** `rbrain-lexicon`'s `FORMATS` gains `oathbreaker` while `formats.yaml` does not list it
- **THEN** lexicon's CI fails, naming `oathbreaker` as extra relative to the catalog — the drift that would otherwise silently desynchronize legality events from forge's read-model is caught before merge

#### Scenario: The catalog grows before the repositories

- **WHEN** `formats.yaml` gains a seventeenth format and `rbrain-forge`'s `FORMATS` still carries sixteen
- **THEN** forge's next CI run fails, naming the identifier missing from the constant

### Requirement: Codex CI validates the catalog and the forge-api enumeration

`bash scripts/validate-formats.sh` run without arguments (or against `rbrain-codex` itself) SHALL verify that `formats.yaml` is well-formed per the first requirement, and that the backtick-quoted identifiers enumerated after "are exactly:" in `openspec/specs/forge-api/spec.md`'s accepted-`format`-identifiers sentence equal the catalog as a set. Codex CI SHALL run this validator.

#### Scenario: The forge-api prose drifts from the catalog

- **WHEN** `formats.yaml` and the accepted-identifiers enumeration in `forge-api/spec.md` disagree
- **THEN** codex CI fails, naming the identifiers present on one side only
