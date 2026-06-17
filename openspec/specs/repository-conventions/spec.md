# repository-conventions Specification

## Purpose
TBD - created by archiving change platform-architecture. Update Purpose after archive.
## Requirements
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
- `runtime`: the primary runtime, one of `rust`, `python`, `typescript`, `none` (for codex and deploy). MUST match the value declared for this context in `language-runtimes/runtime-allocation.yaml`.
- `max_rss_mb`: the memory budget for this repo's primary process, as an integer in megabytes. MUST match the value declared for this context in `language-runtimes/memory-budgets.yaml`. SHALL be `0` for contexts whose `runtime` is `none`.
- `depends_on`: a list of bounded context names this repo calls synchronously (list of strings, MUST be a subset of contexts declared as callees in `sync-graph.yaml` for this caller)
- `publishes`: a list of NATS subject patterns this repo emits (list of strings, each matching `rbrain.<this-context>.<event-name>`)

Additional fields are permitted but tooling SHALL ignore them.

#### Scenario: Tooling reads OWNERSHIP.yaml

- **WHEN** `rbrain-deploy` discovers services to provision
- **THEN** it SHALL parse `OWNERSHIP.yaml` from each repository and SHALL use the six fields above; it SHALL NOT hardcode the list of repositories

#### Scenario: Declared dependencies match the topology

- **WHEN** `OWNERSHIP.yaml` declares `depends_on: [lexicon, oracle]` for the `cortex` repo
- **THEN** validation tooling SHALL confirm that `cortex → lexicon` and `cortex → oracle` are both edges in `sync-graph.yaml`; a mismatch SHALL fail validation

#### Scenario: Runtime matches the platform allocation

- **WHEN** an `rbrain-*` repo's `OWNERSHIP.runtime` does not match the value listed for that context in `language-runtimes/runtime-allocation.yaml`
- **THEN** validation tooling SHALL fail with a clear error naming both sources

#### Scenario: Memory budget matches the platform allocation

- **WHEN** an `rbrain-*` repo's `OWNERSHIP.max_rss_mb` does not match the value listed for that context in `language-runtimes/memory-budgets.yaml`
- **THEN** validation tooling SHALL fail with a clear error naming both sources

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

### Requirement: Health endpoint convention

Every `rbrain-*` sibling whose `OWNERSHIP.runtime` is NOT `none` SHALL expose an HTTP endpoint at `GET /health`. The endpoint SHALL:

- Respond with status `200 OK`.
- Respond with `Content-Type: application/json`.
- Return a JSON object with exactly two string fields, in any key order:
  - `status`: the literal string `"ok"`.
  - `context`: the bounded context name matching `OWNERSHIP.yaml.context`.
- Not require any authentication.
- Not accept any path parameters or query parameters; any extra path segment or query string SHALL be ignored or SHALL cause the endpoint to return its standard 200 response (per-runtime routing defaults are acceptable).

`rbrain-codex` and `rbrain-deploy` (both declared `runtime: none`) are explicitly out of scope and SHALL NOT need to implement this requirement.

Per-sibling `<context>-api` capabilities SHALL reference this requirement when carving `/health` out of their public route closure clause (see "<context>-api capabilities include a route-closure clause" below) rather than restating the `/health` contract.

#### Scenario: Cortex /health smoke test

- **WHEN** an operator issues `GET http://cortex-host/health`
- **THEN** the response SHALL carry status `200`, body `{"status":"ok","context":"cortex"}`; no authentication header SHALL be required

#### Scenario: Lexicon /health smoke test

- **WHEN** an operator issues `GET http://lexicon-host/health`
- **THEN** the response SHALL carry status `200`, body `{"status":"ok","context":"lexicon"}`

#### Scenario: codex and deploy are out of scope

- **WHEN** a contributor checks `rbrain-codex` or `rbrain-deploy` for a `/health` endpoint
- **THEN** they SHALL find no such endpoint; this is conformant because both repos declare `runtime: none` in their OWNERSHIP.yaml

#### Scenario: Extra fields in the response body are forbidden

- **WHEN** the body of `GET /health` is parsed
- **THEN** it SHALL NOT carry any field outside `status` and `context`; adding a third field (e.g., `version`, `git_sha`, `uptime_seconds`) requires a MODIFIED delta on this requirement

### Requirement: <context>-api capabilities include a route-closure clause

Every codex capability whose name matches the `<context>-api` pattern (`lexicon-api`, `cortex-api`, and any future `gateway-api` / `oracle-api` / `forge-api` / `identity-api` / `chronicle-api`) SHALL include at least one requirement whose body enumerates the closed set of public HTTP routes for that bounded context and states that adding any further public route requires a MODIFIED delta on that capability.

The closure-clause requirement SHALL:

- Reference `repository-conventions` as the authoritative source for `GET /health` rather than restating the `/health` contract.
- Explicitly list every public route the capability ratifies (e.g., `POST /chat` for cortex, `GET /cards/{scryfall_id}` + `GET /cards` for lexicon).
- State that any route addition requires a MODIFIED delta on the same capability before the route ships.
- Optionally carve out a `/admin/*` prefix (or any other operator-only prefix) if the sibling has admin endpoints; this MAY live in a separate carve-out change (see `lexicon-api-admin-carveout` precedent).

Capabilities that do NOT match the `<context>-api` pattern (e.g., `bounded-contexts`, `data-stores`, `cortex-bootstrap`) are out of scope — they are not public HTTP contracts.

#### Scenario: A new sibling's <context>-api capability ships without the closure clause

- **WHEN** a contributor proposes a new `oracle-api` capability that lists only the routes it ratifies without a closure clause
- **THEN** the OpenSpec change SHALL be rejected at review; the missing requirement is a violation of this convention

#### Scenario: lexicon-api conforms

- **WHEN** a contributor reads `openspec/specs/lexicon-api/spec.md`
- **THEN** they SHALL find the requirement "No other HTTP routes at v1" enumerating `GET /health`, `GET /cards/{scryfall_id}`, and `GET /cards`; additions require a MODIFIED delta on `lexicon-api`

#### Scenario: cortex-api conforms

- **WHEN** a contributor reads `openspec/specs/cortex-api/spec.md`
- **THEN** they SHALL find the requirement "No other public HTTP routes at v1" enumerating `GET /health` and `POST /chat`; additions require a MODIFIED delta on `cortex-api`

#### Scenario: An admin-prefix carve-out coexists with the closure clause

- **WHEN** a sibling adds `/admin/*` operator-only endpoints (mirroring `lexicon-api-admin-carveout`)
- **THEN** the carve-out SHALL live either inside the same closure-clause requirement or as a sibling requirement on the same `<context>-api` capability; in both cases the closure clause SHALL still hold for the non-`/admin/*` public routes

### Requirement: Port binding honors a PORT environment variable

Every `rbrain-*` sibling whose `OWNERSHIP.runtime` is NOT `none` SHALL read a `PORT` environment variable at startup and bind its HTTP server to that port. When `PORT` is absent or cannot be parsed as a `u16`, the sibling SHALL silently fall back to port `8080`.

The fallback SHALL be silent in the sense of "non-fatal" — a log line MAY be emitted, but the boot SHALL NOT exit on a missing or malformed `PORT`. This matches the convention used by PaaS-style runners (Heroku, Cloud Run, Railway) where `PORT` is injected by the platform and a typo shouldn't crash the pod.

`rbrain-codex` and `rbrain-deploy` (both declared `runtime: none`) are explicitly out of scope and SHALL NOT need to implement this requirement.

Python siblings using `uvicorn` as their CLI entrypoint MAY satisfy this requirement via the `--port` flag with `${PORT:-8080}` substitution rather than reading `PORT` programmatically in `main.py`.

#### Scenario: Default port is 8080

- **WHEN** a sibling starts without `PORT` set in the environment
- **THEN** the HTTP server SHALL bind to port `8080`

#### Scenario: PORT override is honored

- **WHEN** a sibling starts with `PORT=8082` in the environment
- **THEN** the HTTP server SHALL bind to port `8082`; `curl http://host:8082/health` SHALL return the canonical health payload

#### Scenario: Unparseable PORT falls back silently to 8080

- **WHEN** a sibling starts with `PORT=not-a-number` in the environment
- **THEN** the HTTP server SHALL bind to port `8080`; the process SHALL NOT exit non-zero on the parse failure

#### Scenario: codex and deploy are out of scope

- **WHEN** a contributor checks `rbrain-codex` or `rbrain-deploy` for `PORT` handling
- **THEN** they SHALL find none; both repos declare `runtime: none` in their OWNERSHIP.yaml and serve no HTTP surface

### Requirement: Archiving an OpenSpec change is staged with `git add -A`

An archive commit SHALL be staged with `git add -A openspec/` (staging the entire `openspec/` subtree), NOT with `git add <archive-path>` alone.

This is required because archiving relocates `openspec/changes/<name>/` to `openspec/changes/archive/<YYYY-MM-DD>-<name>/` and updates the canonical spec(s) under `openspec/specs/`, and neither the `openspec-archive-change` skill (which uses a shell `mv`) nor the `openspec archive` CLI (which copies then deletes) stages the result with git: afterwards `git status` shows the source paths as deleted and the new archive directory as untracked. Staging only the new archive path produces a commit that adds the archived copy while leaving the pre-archive `openspec/changes/<name>/` directory in the working tree — an incomplete archive.

An archive commit SHALL contain: the deletion of the pre-archive change directory, the new archive directory, and any updated canonical spec files. Review SHALL reject an archive commit in which the pre-archive change directory still exists in the tree.

#### Scenario: Archive commit stages the move and the spec update

- **WHEN** a contributor archives a change (via the skill or the `openspec archive` CLI) and stages with `git add -A openspec/`
- **THEN** the commit SHALL include the removal of `openspec/changes/<name>/`, the added `openspec/changes/archive/<date>-<name>/`, and any modified `openspec/specs/<capability>/spec.md`

#### Scenario: Staging only the new path is rejected

- **WHEN** a contributor stages only the new archive directory (`git add openspec/changes/archive/<date>-<name>`) and commits
- **THEN** the pre-archive `openspec/changes/<name>/` directory SHALL remain in the tree; this is an incomplete archive and SHALL be rejected at review

