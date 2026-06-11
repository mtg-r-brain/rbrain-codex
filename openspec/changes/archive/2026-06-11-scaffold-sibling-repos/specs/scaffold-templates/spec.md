## ADDED Requirements

### Requirement: Three runtime-scoped templates exist

`rbrain-codex` SHALL ship exactly three repository templates under `openspec/specs/scaffold-templates/templates/`:

- `rust-service/` — used for any context whose `runtime` is `rust`
- `python-service/` — used for any context whose `runtime` is `python`
- `typescript-app/` — used for any context whose `runtime` is `typescript`

Contexts whose `runtime` is `none` (`deploy`, `codex`) SHALL NOT be served by any template; they are bespoke repositories outside this scaffold's scope.

#### Scenario: Template selection follows runtime allocation

- **WHEN** the scaffold script is invoked for the `lexicon` context
- **THEN** it SHALL look up `runtime: rust` in `runtime-allocation.yaml` and SHALL use the `rust-service/` template

#### Scenario: Runtime=none contexts are rejected

- **WHEN** the scaffold script is invoked for the `deploy` or `codex` context
- **THEN** it SHALL exit non-zero with a clear message stating that runtime-less contexts are bespoke and not scaffoldable

### Requirement: Each template contains the mandatory repository files

Every template SHALL contain, at minimum:

- `README.md`
- `AGENTS.md`
- `OWNERSHIP.yaml`
- `.github/workflows/ci.yml`
- `Dockerfile`
- `.gitignore`
- A runtime-appropriate hello-world entry point that compiles and boots (per the next requirement)

A template missing any of these files SHALL cause the scaffold script to fail before producing output.

#### Scenario: Template completeness check

- **WHEN** the scaffold script starts
- **THEN** it SHALL verify the presence of the seven mandatory files in the selected template's directory, and SHALL abort if any is missing

### Requirement: Hello-world entry point per template

Each template SHALL ship a minimal hello-world that boots end-to-end in CI:

- `rust-service/`: a single binary crate with `Cargo.toml` and `src/main.rs` exposing an Axum server bound to `0.0.0.0:8080` with a single `GET /health` route returning HTTP 200 and a JSON body `{"status":"ok","context":"${CONTEXT_NAME}"}`.
- `python-service/`: a FastAPI application managed by `uv` (with `pyproject.toml` and `uv.lock`) exposing `GET /health` returning the same JSON shape.
- `typescript-app/`: a Next.js 15 App Router project managed by `pnpm` (with `package.json` and `pnpm-lock.yaml`) shipping a homepage at `src/app/page.tsx` displaying the context name. No `/health` route is required on the frontend.

#### Scenario: Rust scaffold boots and serves /health

- **WHEN** a scaffolded `rust-service`-based repo is built with `cargo build --locked` and the binary is launched
- **THEN** `curl http://localhost:8080/health` SHALL return HTTP 200 with the expected JSON body containing the context name

#### Scenario: Python scaffold boots and serves /health

- **WHEN** a scaffolded `python-service`-based repo is set up with `uv sync` and the FastAPI app is launched (e.g. `uvicorn app.main:app`)
- **THEN** `curl http://localhost:8080/health` SHALL return HTTP 200 with the expected JSON body containing the context name

#### Scenario: Next.js scaffold renders the homepage

- **WHEN** a scaffolded `typescript-app`-based repo is set up with `pnpm install --frozen-lockfile` and the development server is launched
- **THEN** loading the root path in a browser or via `curl` SHALL return HTTP 200 with HTML containing the context name

### Requirement: Templates use envsubst-compatible placeholders only

Every placeholder in any template file SHALL use POSIX shell variable syntax `${VAR_NAME}`. The set of accepted placeholders SHALL be exactly:

- `${CONTEXT_NAME}` — the bounded context name in lowercase kebab-case
- `${RUNTIME}` — one of `rust | python | typescript`
- `${MAX_RSS_MB}` — integer memory budget
- `${RESPONSIBILITY}` — single-sentence responsibility from `catalog.yaml`
- `${NON_RESPONSIBILITIES}` — newline-delimited bullet list pre-expanded by the scaffold script
- `${OWNED_TERMS}` — newline-delimited bullet list pre-expanded by the scaffold script
- `${CALLERS}` — newline-delimited bullet list pre-expanded
- `${CALLEES}` — newline-delimited bullet list pre-expanded
- `${PUBLISHES}` — newline-delimited bullet list pre-expanded (subject patterns)

Any other `${...}` token in a template SHALL be passed through unchanged by `envsubst` and SHALL NOT be substituted.

#### Scenario: Unknown placeholder is preserved verbatim

- **WHEN** a template file contains `${HOME}` or any other token outside the allowed set
- **THEN** the scaffold script's `envsubst` invocation SHALL be restricted to the allowed token list, and the unknown token SHALL appear unchanged in the output

#### Scenario: Allowed placeholder is substituted

- **WHEN** `OWNERSHIP.yaml` in a template contains `context: ${CONTEXT_NAME}` and the script is invoked for `lexicon`
- **THEN** the output file SHALL contain `context: lexicon`

### Requirement: CI workflow per template covers build, lint, format, validate

Each template's `.github/workflows/ci.yml` SHALL run, in this order, the following classes of checks against the scaffolded repository:

- a build step compiling all source
- a lint step enforcing the project's lint rules with warnings treated as errors
- a format step verifying formatting conformance (failing on drift)
- a validate step fetching the latest `scripts/validate-repo.sh` from `rbrain-codex`'s `main` branch and running it against the current repository

Concrete tool choices per template:

- `rust-service`: `cargo build --locked` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt --check` / `validate-repo.sh`
- `python-service`: `uv sync` / `uv run ruff check` / `uv run ruff format --check` / `uv run mypy` / `validate-repo.sh`
- `typescript-app`: `pnpm install --frozen-lockfile` / `pnpm tsc --noEmit` / `pnpm eslint` / `pnpm prettier --check` / `validate-repo.sh`

Integration tests, Docker image builds, SBOM generation, and deployment steps SHALL NOT be part of this CI workflow.

#### Scenario: CI fails on a clippy warning

- **WHEN** a Rust sibling repo introduces code that triggers a clippy warning
- **THEN** the CI job SHALL fail because clippy is invoked with `-D warnings`

#### Scenario: CI uses the latest validate-repo.sh

- **WHEN** `validate-repo.sh` on `rbrain-codex` `main` is updated with a new check
- **THEN** the next CI run on any sibling repo SHALL exercise the new check without requiring a change in the sibling repo

### Requirement: Templates carry their own Dockerfile

Each template SHALL ship a minimal `Dockerfile` capable of producing a runnable image of the hello-world entry point. The Dockerfile SHALL use a multi-stage build (build stage + runtime stage) and SHALL produce an image whose runtime stage is based on a minimal distroless or alpine image appropriate to the runtime.

#### Scenario: Image build succeeds

- **WHEN** a scaffolded repo's `Dockerfile` is built with `docker build .`
- **THEN** the build SHALL succeed and produce a runnable image that, when started, serves the hello-world endpoint or homepage on its declared port

#### Scenario: Image is not built in CI

- **WHEN** the template's CI workflow runs
- **THEN** it SHALL NOT execute `docker build`; image builds are a future deployment concern outside this scaffold's scope
