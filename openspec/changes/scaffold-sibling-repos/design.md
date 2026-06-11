## Context

After `platform-architecture` and `technology-stack`, every contract a sibling repo must honor is locked: which BC it implements (`catalog.yaml`), who it talks to (`sync-graph.yaml`), which runtime it uses (`runtime-allocation.yaml`), which version floors apply, and what its `OWNERSHIP.yaml` must contain. The next concrete step is to materialize that contract as nine sibling repositories. Doing this nine times by hand would guarantee drift: typos in subject names, forgotten fields, inconsistent CI templates. This change designs a one-shot scaffolder so the materialization is mechanical and conformant by construction.

The constraint shaping every decision below is **the scaffold is one-shot, not a framework**. Nine invocations happen once each (with rare re-runs if a template evolves). Investing in templating sophistication would not pay off.

## Goals / Non-Goals

**Goals:**

- Make the nine sibling repos conformant by construction: passing `validate-repo.sh` immediately, building green in CI, no manual edits required for boilerplate.
- Keep the templates auditable: anyone can read `rust-service/AGENTS.md` or `python-service/Dockerfile` and understand what every sibling will look like.
- Resolve every placeholder from authoritative codex sources (`catalog.yaml`, `sync-graph.yaml`, `runtime-allocation.yaml`, `memory-budgets.yaml`). Hand-typed values are forbidden inside templates.
- Stay POSIX-portable: the scaffold script runs on macOS and Linux with default tooling. No Python dependency for the scaffolder itself.

**Non-Goals:**

- Producing a generic project scaffolder usable outside `rbrain-*`. This is a bespoke tool, not a product.
- Supporting template inheritance, conditional blocks, or per-context branching beyond simple value substitution. Each runtime gets one template; differences across BCs are expressed through placeholder values only.
- Provisioning the actual GitHub repositories, configuring branch protection, or wiring secrets. The script outputs a directory tree; the human creates the GitHub repo and pushes.
- Implementing observability, secret management, runtime configuration. Those belong to future changes.

## Decisions

### D1. Three templates indexed by runtime, not by BC

The scaffolder hosts exactly three templates: `rust-service/`, `python-service/`, `typescript-app/`. The template chosen for a given context is the one whose name corresponds to the context's `runtime` in `runtime-allocation.yaml`. Contexts with `runtime: none` (`deploy`, `codex`) are NOT scaffolded by this tool — they are bespoke repos (`codex` already exists; `deploy` will be hand-crafted later).

**Rationale:** The differences across BCs that share a runtime are values, not structure. `rbrain-lexicon` and `rbrain-oracle` are both Rust + Axum + SQLx services; only their `OWNERSHIP.yaml` fields, their service name in `main.rs`, and their `AGENTS.md` text differ. A per-runtime template captures the shared structure once.

**Alternatives considered:**

- **One template per BC** — rejected: nine copies of the same Rust boilerplate, drift guaranteed.
- **One generic template with overrides** — rejected: requires a real templating system (jinja, copier), pulls Python as a build dep, harder to audit.

### D2. Placeholder substitution via `envsubst` with `${VAR}` tokens

Every variable in a template uses POSIX shell variable syntax: `${CONTEXT_NAME}`, `${RUNTIME}`, `${MAX_RSS_MB}`, etc. The scaffold script exports these values into the environment and pipes each template file through `envsubst` to produce the output file.

**Rationale:** `envsubst` is part of `gettext` and ships with every developer toolchain we care about (macOS via `gettext` Homebrew formula, Linux universally). It does exactly one thing — text substitution — with no surprises. Template files remain valid in their own right (a Rust file with `${CONTEXT_NAME}` in an identifier slot is invalid until substituted, which is exactly what we want — no template file should accidentally compile or run).

**Alternatives considered:**

- **`sed` substitution** — rejected: escaping rules are treacherous when the substituted value contains slashes or special characters.
- **`jinja2` (Python) or `copier`** — rejected: Python dependency for a one-shot script, overkill for text replacement.
- **`yq` + `jq`** — rejected for the substitution role; they shine at YAML/JSON manipulation, not generic text. They are used elsewhere in the script (D4).

### D3. Substituted variables come exclusively from codex YAML sources

Before running `envsubst`, the script loads four authoritative files and exports their values to the environment:

- `openspec/specs/bounded-contexts/catalog.yaml` → `CONTEXT_NAME`, `RESPONSIBILITY`, `NON_RESPONSIBILITIES`, `OWNED_TERMS`
- `openspec/specs/service-topology/sync-graph.yaml` → `CALLERS`, `CALLEES`, `PUBLISHES_PATTERN`
- `openspec/specs/language-runtimes/runtime-allocation.yaml` → `RUNTIME`
- `openspec/specs/language-runtimes/memory-budgets.yaml` → `MAX_RSS_MB`

The script SHALL NOT accept any of these values as command-line flags. The only argument is the context name. If a value is missing from its source, the script exits non-zero with an error pointing at the missing entry.

**Rationale:** A single source of truth per fact. The day a sibling's runtime changes, only `runtime-allocation.yaml` is edited; re-running the scaffolder updates the repo without anyone editing two files. CLI flags would invite drift.

### D4. List values use newline-delimited expansion

YAML list fields (`non_responsibilities`, `callers`, `callees`, `publishes`) need to land as bullet lists in `AGENTS.md` and as YAML lists in `OWNERSHIP.yaml`. The script reads the list via `yq -r '.contexts.lexicon.non_responsibilities[]'`, joins with newlines and a list-prefix (`- `), and exports the result as a single shell variable. The template uses `${NON_RESPONSIBILITIES}` in a single line; the substituted value carries its own newlines.

**Rationale:** Avoids a per-list-item loop in the template (which `envsubst` cannot express). Keeps the template flat and readable.

**Alternatives considered:**

- **Per-item placeholder slots** (`${NON_RESP_1}`, `${NON_RESP_2}`) — rejected: caps the list at a fixed size, ugly when lists are short.
- **A second pass with a loop construct** — rejected: requires moving away from `envsubst`.

### D5. Hello-world per template exposes a `/health` endpoint or homepage

Each template ships a minimal entry point that the runtime can boot:

- `rust-service/src/main.rs`: Axum 0.7 server binding `0.0.0.0:8080`, single route `GET /health` returning `200 OK` with body `{"status":"ok","context":"${CONTEXT_NAME}"}`.
- `python-service/app/main.py`: FastAPI app exposing `GET /health` returning the same JSON shape.
- `typescript-app/src/app/page.tsx`: Next.js 15 App Router homepage showing the context name and a placeholder paragraph. No `/health` route on the frontend.

**Rationale:** Booting the runtime end-to-end in CI catches more drift than `cargo check` alone (missing crate, wrong Tokio feature flags, Python version mismatch). `/health` is the lowest-effort endpoint that still proves the binary runs. The frontend is intentionally a page, not an endpoint, because its runtime is meaningfully different (SSR + RSC).

### D6. CI workflow per template covers build, lint, format, validate

Each template's `.github/workflows/ci.yml` runs the relevant checks for its runtime:

- `rust-service`: `cargo build --locked`, `cargo clippy -- -D warnings`, `cargo fmt --check`, then `bash <(curl rbrain-codex/scripts/validate-repo.sh)`.
- `python-service`: `uv sync` (or `pip install -e .`), `ruff check`, `ruff format --check`, `mypy`, `pytest --collect-only`, then `validate-repo.sh`.
- `typescript-app`: `pnpm install --frozen-lockfile`, `pnpm tsc --noEmit`, `pnpm eslint`, `pnpm prettier --check`, then `validate-repo.sh`.

Integration tests, Docker image build, and SBOM generation are explicitly out of scope.

**Rationale:** Catches the common dumb mistakes (warning treated as error, formatter drift, broken validate). Stops short of the heavier checks that need infrastructure (Postgres, Redis, NATS), which belong to per-context capability specs.

**Open question:** how `validate-repo.sh` is shared across repos — vendor it into each repo, or pull it on each CI run? Decision deferred to tasks (D-Open-1).

### D7. The scaffold script lives at `scripts/scaffold-repo.sh` in `rbrain-codex`

Single Bash script, invoked as `bash scripts/scaffold-repo.sh <context-name> [<target-dir>]`. Default target is `../rbrain-<context-name>/` relative to `rbrain-codex`. Exits non-zero on any error (missing context, missing YAML field, validate failure).

**Rationale:** A single script with no flags is the smallest surface that gets the job done. POSIX Bash because the tooling expectations are uniform.

## Risks / Trade-offs

- **Templates duplicate boilerplate across runtimes.** → Mitigation: that's intentional. Three templates is the minimum non-trivial number, and they are small enough to read in five minutes each.
- **`envsubst` will substitute any environment variable, not just the intended placeholders.** A stray `$HOME` or `$PATH` in a template would be silently replaced. → Mitigation: the script uses `envsubst '$VAR1 $VAR2 ...'` with an explicit allowlist of placeholders; any other `${...}` in templates passes through unchanged.
- **Templates can rot if specs evolve and templates are not re-run.** → Mitigation: a CI job in `rbrain-codex` periodically dry-runs the scaffolder against every catalog context and diffs the output against the current sibling repo HEAD, failing if drift is detected. Tracked as a hand-off task.
- **The scaffolder does not handle re-scaffolding gracefully**: a re-run would overwrite files the maintainer may have edited. → Mitigation: the script refuses to write into a non-empty target directory unless `--force` is passed; documented in the checklist.
- **Frontend template ships a placeholder homepage that is not the eventual `app` layout.** → Acceptable: the homepage is overwritten by the first product spec that addresses the frontend.

## Migration Plan

There is nothing currently deployed. The execution path:

1. Land this change (proposal + design + 2 specs + tasks) in `rbrain-codex`.
2. Implement the tasks (templates + script + checklist + drift CI job).
3. Maintainer runs `scripts/scaffold-repo.sh <context>` for each of the seven Rust/Python/TS siblings (`gateway`, `identity`, `lexicon`, `oracle`, `forge`, `chronicle`, `cortex`, `app`). `deploy` and `codex` are out of scope.
4. Maintainer follows the per-context checklist (create GitHub repo, push, enable CI).

Rollback is trivial: the codex change can be reverted; the sibling repos, if already created, can be archived or deleted from GitHub.

## Open Questions

- **D-Open-1: how is `validate-repo.sh` shared across repos?** Options: (a) vendor a copy into each scaffolded repo (pin to a codex revision, manual bumps), (b) fetch from codex `main` at every CI run (always up to date, requires GitHub access), (c) publish it as a reusable GitHub Action. Defer to tasks.
- **D-Open-2: which Rust workspace layout?** Single binary crate vs. a workspace with a `lib` and `bin`. Defer to whichever the first Rust template author prefers; document the choice in the template's `AGENTS.md`.
- **D-Open-3: Python project manager.** `uv` vs `pip` + `pip-tools` vs `poetry`. `uv` is the fastest-growing but young. Recommendation: `uv`; flag in tasks for confirmation.
- **D-Open-4: TypeScript package manager.** `pnpm` vs `npm` vs `bun`. Recommendation: `pnpm` (good lockfile, mature). Flag in tasks for confirmation.
