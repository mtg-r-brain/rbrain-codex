# codex — Agent Bootstrap

Conformant to the AGENTS.md baseline defined in `openspec/specs/repository-conventions/spec.md`.

## Responsibility

Holds the OpenSpec proposals, specs, and ADRs that govern the platform.

## Non-responsibilities

The following concerns are explicitly NOT owned by `codex`. Route them elsewhere:

- runtime configuration → `rbrain-deploy`
- secret storage → out-of-band (vault, environment, never committed)
- business logic of any context → the context's own repo

## Owned vocabulary

- `spec`, `capability`, `change`, `adr`, `proposal`, `requirement`, `scenario`

## Synchronous callers / callees

None. `codex` is a documentation repo; it has no runtime and does not appear in `openspec/specs/service-topology/sync-graph.yaml`.

## Published events

None. `codex` has no runtime.

## Runtime

This repo's primary runtime is `none` with `max_rss_mb: 0` (declared in `OWNERSHIP.yaml`).

## Working in this repo

### OpenSpec workflow

Every platform-level change goes through a four-artifact OpenSpec change:

| Phase | Artifact | When to write |
|---|---|---|
| Why | `proposal.md` | First, before any technical decision |
| What | `specs/<capability>/spec.md` | One per capability listed in the proposal; testable requirements |
| How | `design.md` | Architectural decisions, alternatives considered, trade-offs |
| Do | `tasks.md` | Checklist for the apply phase |

A change starts at `openspec/changes/<name>/` and stays there until archived. Archive promotes the specs into `openspec/specs/<capability>/` as the live contract.

### Validators

Run before committing:

```sh
bash scripts/validate-catalog.sh        # bounded-contexts/catalog.yaml
bash scripts/validate-topology.sh       # service-topology/sync-graph.yaml (DAG check)
bash scripts/validate-runtimes.sh       # language-runtimes YAMLs vs. catalog and ceiling
bash scripts/validate-data-stores.sh    # data-stores/postgres-roles.yaml
bash scripts/validate-subjects.sh       # NATS subjects across every OWNERSHIP.yaml
bash scripts/validate-llm-config.sh     # llm-abstraction/providers.yaml
bash scripts/validate-repo.sh .         # this repo's mandatory files + OWNERSHIP.yaml
```

CI runs all seven on every push to `main` and every pull request — workflow at `.github/workflows/ci.yml`.

### Scaffold tooling

`scripts/scaffold-repo.sh <context>` materializes a sibling `rbrain-*` repository from one of the three runtime templates under `openspec/specs/scaffold-templates/templates/`. After editing any template or any YAML source, refresh the checked-in baselines:

```sh
bash scripts/refresh-baselines.sh        # regenerates the eight rbrain-<ctx> baselines
```

A separate CI job (`scaffold-drift`) dry-runs the scaffolder and diffs against the baselines on every push. A drift means either a template edit needs a baseline refresh, or a YAML source change has knock-on effects on the scaffolded output — both are caught at PR time.

Smoke tests for the scaffolder live at `scripts/tests/scaffold-repo/run.sh`.

If a change modifies `catalog.yaml`, `sync-graph.yaml`, `runtime-allocation.yaml`, or `memory-budgets.yaml`, expect downstream changes to sibling repos' `OWNERSHIP.yaml` files. Drift is caught by `validate-repo.sh` running in each sibling's CI (it fetches the latest validator + sources from this repo's `main`).

### Per-sibling public-API specs

Each sibling's public HTTP surface lives in codex under a capability named `<context>-api` — for example, `lexicon-api` holds the contract for `rbrain-lexicon`. When a sibling ships a new public endpoint, the PR proposing that endpoint SHALL include a MODIFIED delta on its `<context>-api` capability in codex.

This convention applies to public-facing siblings only. `deploy` and `codex` have no HTTP surface and no `<context>-api` capability. Internal specs (Scryfall sync internals, search algorithm details, etc.) live in the sibling repo's own `openspec/` — codex carries only the cross-context contract.

### Conventions

- All written artifacts (specs, ADRs, commits, PRs, GitHub issues) are in **English**.
- Commit messages follow [Gitmoji](https://gitmoji.dev/) per the team convention.
- One `📝 spec` commit per change during the planning phase — covering proposal, design, spec deltas, and tasks together; the **change** is the atomic unit, not each artifact — followed by one `📦 archive` commit at archive time. During the apply phase, one commit per task group.

### Reference templates

`openspec/specs/repository-conventions/templates/` carries the canonical `OWNERSHIP.yaml` and `AGENTS.md` every `rbrain-*` repository must derive from. Placeholders use POSIX shell syntax `${VAR}` and are resolved by the (future) `scripts/scaffold-repo.sh` tool — see `openspec/changes/scaffold-sibling-repos/`.
