## ADDED Requirements

### Requirement: Mandatory files at repository root

Every `rbrain-*` repository SHALL contain at its root, at minimum: `README.md`, `AGENTS.md`, `OWNERSHIP.yaml`, and a CI manifest appropriate to its hosting platform (`.github/workflows/ci.yml` for GitHub Actions). A repository missing any of these files SHALL be considered non-conformant and SHALL NOT be deployed.

#### Scenario: Conformance check on a new repository

- **WHEN** a new `rbrain-*` repository is initialized
- **THEN** the four mandatory files SHALL be present in the initial commit

#### Scenario: Conformance check in CI

- **WHEN** any push or pull request runs CI
- **THEN** CI SHALL verify the presence of the four mandatory files and SHALL fail the job if any is missing

### Requirement: OWNERSHIP.yaml schema

Each `OWNERSHIP.yaml` file SHALL contain the following top-level fields:

- `context`: the bounded context name (string, kebab-case, MUST match `rbrain-<context>` repo name)
- `owner`: the human or team primarily responsible (string)
- `runtime`: the primary runtime, one of `rust`, `python`, `typescript`, `none` (for codex and deploy)
- `depends_on`: a list of bounded context names this repo calls synchronously (list of strings, MUST be a subset of contexts declared as callees in `sync-graph.yaml` for this caller)
- `publishes`: a list of NATS subject patterns this repo emits (list of strings, each matching `rbrain.<this-context>.<event-name>`)

Additional fields are permitted but tooling SHALL ignore them.

#### Scenario: Tooling reads OWNERSHIP.yaml

- **WHEN** `rbrain-deploy` discovers services to provision
- **THEN** it SHALL parse `OWNERSHIP.yaml` from each repository and SHALL use the five fields above; it SHALL NOT hardcode the list of repositories

#### Scenario: Declared dependencies match the topology

- **WHEN** `OWNERSHIP.yaml` declares `depends_on: [lexicon, oracle]` for the `cortex` repo
- **THEN** validation tooling SHALL confirm that `cortex → lexicon` and `cortex → oracle` are both edges in `sync-graph.yaml`; a mismatch SHALL fail validation

### Requirement: AGENTS.md baseline content

Every `AGENTS.md` SHALL declare at minimum: the bounded context name, its `responsibility` statement (copied verbatim from `catalog.yaml`), its `non_responsibilities`, its allowed synchronous callers and callees (derived from `sync-graph.yaml`), and its published NATS subjects (matching `OWNERSHIP.yaml.publishes`). Additional sections (runbooks, local development setup) are permitted and encouraged.

#### Scenario: Agent bootstraps into an unfamiliar repository

- **WHEN** an AI agent opens an `rbrain-*` repository it has not previously interacted with
- **THEN** reading `AGENTS.md` alone SHALL be sufficient to know what the context owns, what it does NOT own, who calls it, what it calls, and what events it publishes

#### Scenario: AGENTS.md and OWNERSHIP.yaml are consistent

- **WHEN** validation tooling runs
- **THEN** it SHALL verify that the AGENTS.md callers/callees match the edges in `sync-graph.yaml` and that the published subjects match `OWNERSHIP.yaml.publishes`; any discrepancy SHALL fail validation

### Requirement: Internal repository structure is not prescribed

Beyond the mandatory root files defined above, the internal folder layout, module organization, and build configuration of each `rbrain-*` repository SHALL be left to the context's owner. No platform-wide convention SHALL be enforced on subdirectory naming, source-folder layout, or test organization.

#### Scenario: Repository owner chooses idiomatic layout

- **WHEN** the `rbrain-cortex` (Python) maintainer organizes the repo with `src/cortex/` and `tests/`
- **THEN** this SHALL be accepted as conformant, even though it differs from the `src/main/rust/` layout a Rust repo might use

#### Scenario: No central directive overrides local choice

- **WHEN** a contributor proposes adding a platform-wide rule about folder naming
- **THEN** the proposal SHALL be rejected unless it first amends this requirement via an OpenSpec change explaining the cost-benefit
