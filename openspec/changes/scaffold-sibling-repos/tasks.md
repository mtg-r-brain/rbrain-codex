## 1. scaffold-templates capability — rust-service

- [x] 1.1 Create `openspec/specs/scaffold-templates/templates/rust-service/Cargo.toml` declaring a single binary crate named `${CONTEXT_NAME}` pinning Axum `0.7`, Tokio `1.40` with `["rt-multi-thread", "macros"]`, and Tower 0.5.
- [x] 1.2 Create `openspec/specs/scaffold-templates/templates/rust-service/src/main.rs` with a minimal Axum app exposing `GET /health` returning `{"status":"ok","context":"${CONTEXT_NAME}"}` and binding `0.0.0.0:8080`.
- [x] 1.3 Create the template's `README.md`, `AGENTS.md`, `OWNERSHIP.yaml` (with `${RUNTIME}`, `${MAX_RSS_MB}`, `${CONTEXT_NAME}`, `${CALLEES}`, `${PUBLISHES}` placeholders), `.gitignore` (Rust standard), and `rust-toolchain.toml` pinning `>= 1.83.0`.
- [x] 1.4 Create `.github/workflows/ci.yml` running `cargo build --locked`, `cargo clippy --all-targets -- -D warnings`, `cargo fmt --check`, then fetching `validate-repo.sh` from `https://raw.githubusercontent.com/<owner>/rbrain-codex/main/scripts/validate-repo.sh` and executing it.
- [x] 1.5 Create a multi-stage `Dockerfile` (builder on `rust:1.83-slim`, runtime on `gcr.io/distroless/cc-debian12`) producing a `~10 MB` image that serves `/health`.

## 2. scaffold-templates capability — python-service

- [x] 2.1 Create `openspec/specs/scaffold-templates/templates/python-service/pyproject.toml` declaring `python = ">=3.12"`, `fastapi >= 0.115`, `uvicorn[standard]`, and the dev tools (`ruff`, `mypy`).
- [x] 2.2 Create `openspec/specs/scaffold-templates/templates/python-service/app/main.py` with a FastAPI app exposing `GET /health` returning `{"status":"ok","context":"${CONTEXT_NAME}"}`.
- [x] 2.3 Create the template's `README.md`, `AGENTS.md`, `OWNERSHIP.yaml` (same placeholder set as rust-service), `.gitignore` (Python standard + `.venv/`, `uv.lock` kept).
- [x] 2.4 Create `.github/workflows/ci.yml` running `uv sync`, `uv run ruff check .`, `uv run ruff format --check .`, `uv run mypy app`, `uv run pytest --collect-only`, then fetching and running `validate-repo.sh`.
- [x] 2.5 Create a multi-stage `Dockerfile` (builder installing dependencies via `uv`, runtime on `python:3.12-slim`) producing an image that serves `/health` via `uvicorn`.
- [x] 2.6 Generate the initial `uv.lock` against the dependency set and commit it alongside `pyproject.toml`.

## 3. scaffold-templates capability — typescript-app

- [ ] 3.1 Create `openspec/specs/scaffold-templates/templates/typescript-app/package.json` declaring Next.js 15, React 18, TypeScript 5.x, pnpm as the manager, and the scripts (`build`, `lint`, `dev`, `start`, `tsc:check`).
- [ ] 3.2 Create `openspec/specs/scaffold-templates/templates/typescript-app/src/app/page.tsx` rendering a minimal homepage displaying `${CONTEXT_NAME}` and a short placeholder paragraph; the rest of the App Router skeleton (`layout.tsx`, `globals.css`) is included.
- [ ] 3.3 Create the template's `README.md`, `AGENTS.md`, `OWNERSHIP.yaml`, `.gitignore` (Node + Next.js standard, keep `pnpm-lock.yaml`), `.eslintrc.cjs`, `.prettierrc.json`, `tsconfig.json`.
- [ ] 3.4 Create `.github/workflows/ci.yml` running `pnpm install --frozen-lockfile`, `pnpm tsc --noEmit`, `pnpm lint`, `pnpm prettier --check .`, then fetching and running `validate-repo.sh`.
- [ ] 3.5 Create a multi-stage `Dockerfile` (builder on `node:22-alpine` running `pnpm build`, runtime on `node:22-alpine` running `pnpm start`) producing an image that serves the homepage.
- [ ] 3.6 Generate the initial `pnpm-lock.yaml` against the dependency set and commit it.

## 4. scaffold-procedure capability — script

- [ ] 4.1 Create `scripts/scaffold-repo.sh` parsing the positional `<context-name>` and optional `<target-dir>` and `--force` flag; reject any other argument.
- [ ] 4.2 Implement YAML loading: for the given context, fetch `runtime`, `max_rss_mb`, `responsibility`, `non_responsibilities`, `owned_terms`, `callers`, `callees`, `publishes` from the four authoritative files via `yq -r`; fail with a precise error on any missing field.
- [ ] 4.3 Implement list pre-expansion: for each list-typed value, produce a newline-delimited bullet string (`- item`); export every variable for `envsubst`.
- [ ] 4.4 Select the template directory based on `${RUNTIME}` (fail explicitly for `runtime: none`).
- [ ] 4.5 Refuse non-empty target unless `--force` is passed; on `--force`, overwrite template-managed files only.
- [ ] 4.6 Walk the selected template, piping each file through `envsubst '$CONTEXT_NAME $RUNTIME $MAX_RSS_MB $RESPONSIBILITY $NON_RESPONSIBILITIES $OWNED_TERMS $CALLERS $CALLEES $PUBLISHES'` and writing to the corresponding path under `<target-dir>`.
- [ ] 4.7 After writing, invoke `scripts/validate-repo.sh <target-dir>` and propagate its exit code; on success, print a one-line pointer to `openspec/specs/scaffold-procedure/checklist.md`.
- [ ] 4.8 Add unit tests for the script under `scripts/tests/scaffold-repo/` covering: happy path for each runtime, unknown context, missing YAML field, runtime=none rejection, non-empty target without --force, --force preserves unrelated files.

## 5. scaffold-procedure capability — checklist & drift CI

- [ ] 5.1 Create `openspec/specs/scaffold-procedure/checklist.md` documenting the post-scaffold steps (create GH repo named `rbrain-<context>`, push initial commit, enable Actions, branch protection on `main`, required CI checks, add to `rbrain-deploy` discovery, optional Discord announcement).
- [ ] 5.2 For each runtime!=none context (`gateway`, `identity`, `lexicon`, `oracle`, `forge`, `chronicle`, `cortex`, `app`), generate a baseline scaffold at `openspec/specs/scaffold-procedure/baselines/rbrain-<context>/` by running the scaffold script against a temporary dir and copying the result. Commit these eight baseline trees.
- [ ] 5.3 Add a CI job `scaffold-drift` to `rbrain-codex`'s workflow that, for each of the eight contexts, dry-runs `scripts/scaffold-repo.sh <context> /tmp/scaffold-<context>` and runs `diff -r /tmp/scaffold-<context> openspec/specs/scaffold-procedure/baselines/rbrain-<context>`; fail the job on any diff.
- [ ] 5.4 Add a developer-facing helper `scripts/refresh-baselines.sh` that regenerates every baseline in-place (used to update baselines after a legitimate template change in the same commit).

## 6. Hand-off

- [ ] 6.1 Update `rbrain-codex/README.md` to document the scaffold workflow (one paragraph + `scaffold-repo.sh` usage + checklist pointer).
- [ ] 6.2 Update `rbrain-codex/AGENTS.md` to mention the scaffold script, the drift job, and the refresh helper.
- [ ] 6.3 Once tasks 1.x–5.x land and the drift job is green for all eight contexts, the maintainer (out of OpenSpec) runs `scripts/scaffold-repo.sh` for each of the eight contexts, follows the checklist, and creates the eight sibling repos.
- [ ] 6.4 Archive this change via `openspec archive scaffold-sibling-repos` once tasks 1.x–5.x are complete and CI is green. (Task 6.3 is outside the spec's scope but tracked for visibility.)
