# bounded-contexts Specification

## Purpose
TBD - created by archiving change platform-architecture. Update Purpose after archive.
## Requirements
### Requirement: Authoritative catalog of bounded contexts

The platform SHALL maintain an authoritative, machine-readable catalog of all bounded contexts in `openspec/specs/bounded-contexts/catalog.yaml`. The catalog SHALL list exactly ten entries: `gateway`, `identity`, `lexicon`, `oracle`, `forge`, `cortex`, `chronicle`, `app`, `deploy`, `codex`. Adding, removing, or renaming a bounded context SHALL require an OpenSpec change that modifies this requirement and updates the catalog atomically.

#### Scenario: Catalog is the single source of truth

- **WHEN** any tool, agent, or contributor needs to enumerate the bounded contexts of the platform
- **THEN** the tool SHALL read `openspec/specs/bounded-contexts/catalog.yaml` and SHALL NOT rely on hardcoded lists in code or documentation elsewhere

#### Scenario: Adding a new bounded context

- **WHEN** a contributor proposes an 11th bounded context
- **THEN** the proposal SHALL ship as an OpenSpec change that updates this requirement and adds the new entry to `catalog.yaml` in the same commit

### Requirement: Responsibility statement per context

Each bounded context entry in `catalog.yaml` SHALL declare a `responsibility` field (one sentence, present tense, active voice) and a `non_responsibilities` field (a list of at least one explicit exclusion). The responsibility SHALL be specific enough that a reader can decide, given any feature request, whether the context owns it.

#### Scenario: Reader can route a feature

- **WHEN** a contributor reads `catalog.yaml` and wants to determine which context owns "parse an MTGA-format deck list"
- **THEN** exactly one context's `responsibility` SHALL match (here: `forge`) and no other context's `responsibility` SHALL ambiguously cover the same concern

#### Scenario: Non-responsibility prevents drift

- **WHEN** a contributor considers adding card-search logic to `oracle`
- **THEN** `oracle.non_responsibilities` SHALL list "card catalogue and full-text search" so the contributor knows to route the work to `lexicon` instead

### Requirement: Domain vocabulary is owned

Each bounded context SHALL declare an `owned_terms` list in `catalog.yaml` enumerating the domain terms it defines authoritatively. A term SHALL appear in at most one context's `owned_terms`. When a context needs to refer to a term owned by another context, it SHALL alias the term in its own AGENTS.md rather than redefining it.

#### Scenario: Term ownership is unique

- **WHEN** `catalog.yaml` is validated
- **THEN** no term SHALL appear in the `owned_terms` of two distinct contexts

#### Scenario: Cross-context term usage

- **WHEN** `cortex` needs to mention the term "deck" (owned by `forge`)
- **THEN** `cortex`'s AGENTS.md SHALL reference the term as `forge.deck` or declare an alias, and SHALL NOT redefine "deck" with a different meaning

### Requirement: Repository name follows context name

Each bounded context SHALL be implemented in exactly one repository named `rbrain-<context>`, where `<context>` is the catalog entry name in lowercase kebab-case. A repository name SHALL NOT collide with any other context's name.

#### Scenario: Repository discovery

- **WHEN** an agent or tool needs to locate the repository implementing the `lexicon` context
- **THEN** the repository SHALL be at the path `rbrain-lexicon` relative to the platform root and SHALL be the only repository matching that name

#### Scenario: Multi-repo claim is rejected

- **WHEN** a contributor proposes splitting one context across two repositories
- **THEN** the proposal SHALL be rejected unless it first amends this requirement via an OpenSpec change

