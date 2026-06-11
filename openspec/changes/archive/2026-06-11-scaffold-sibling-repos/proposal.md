## Why

`platform-architecture` and `technology-stack` froze the contract every `rbrain-*` repo must honor (bounded contexts, topology, conventions, runtime, version floors, memory budgets). Nine sibling repositories now need to be created against that contract: `rbrain-gateway`, `rbrain-identity`, `rbrain-lexicon`, `rbrain-oracle`, `rbrain-forge`, `rbrain-chronicle`, `rbrain-cortex`, `rbrain-app`, `rbrain-deploy`. Without a templated scaffold, each repo's initial commit would re-derive the same boilerplate from the specs by hand — error-prone, inconsistent across repos, and likely to drift from the contract as the specs evolve.

This change does NOT create the nine repositories. It produces the scaffolding artefacts (templates, script, checklist) inside `rbrain-codex` so that the actual repo creation, done by the maintainer afterward, is mechanical and conformant by construction.

## What Changes

- Introduce three repository templates under `openspec/specs/scaffold-templates/templates/`: `rust-service/`, `python-service/`, `typescript-app/`. Each template carries the four mandatory files defined by `repository-conventions` (README.md, AGENTS.md, OWNERSHIP.yaml, `.github/workflows/ci.yml`), a runtime-appropriate Dockerfile, a `.gitignore`, and a minimal hello-world entry point that compiles and runs.
- Each template uses placeholder tokens (`{{CONTEXT_NAME}}`, `{{RESPONSIBILITY}}`, `{{NON_RESPONSIBILITIES}}`, `{{CALLERS}}`, `{{CALLEES}}`, `{{PUBLISHES}}`, `{{RUNTIME}}`, `{{MAX_RSS_MB}}`) which the scaffold script substitutes from the codex's authoritative YAML sources (`catalog.yaml`, `sync-graph.yaml`, `runtime-allocation.yaml`, `memory-budgets.yaml`).
- Introduce a scaffold procedure: `scripts/scaffold-repo.sh <context-name>` that, given a context name, resolves its runtime, picks the right template, performs all substitutions, writes the result into a target directory, and runs `validate-repo.sh` against it before exiting.
- Introduce a per-context checklist at `openspec/specs/scaffold-procedure/checklist.md` documenting the post-scaffold steps the maintainer performs (create GitHub repo, push initial commit, enable CI, register in `rbrain-deploy`).
- The scaffold does NOT include observability wiring, secret management, or any business logic — those belong to per-context capability specs in future changes.

## Capabilities

### New Capabilities

- `scaffold-templates`: The three runtime-specific repository templates that any new `rbrain-*` repo derives from. Defines what each template MUST contain, the placeholder tokens it MUST expose, and the conformance guarantees it provides.
- `scaffold-procedure`: The script and the human checklist that turn a context name into a conformant repository. Defines the script's interface, its inputs (codex YAML sources), its outputs (a directory tree), and the post-scaffold steps the human owns.

### Modified Capabilities

None. This change builds on `platform-architecture` (specs not yet archived) and `technology-stack` (specs not yet archived) but does not amend any prior requirement.

## Impact

- **`rbrain-codex` repo layout**: new top-level `openspec/specs/scaffold-templates/` and `openspec/specs/scaffold-procedure/` directories, new `scripts/scaffold-repo.sh`.
- **Future repo creation**: the maintainer (or a CI bot) runs `scripts/scaffold-repo.sh <context>` once per sibling, then follows the checklist. Nine invocations produce nine conformant repos.
- **Future `deployment-topology`** (downstream): can extend the template's `ci.yml` and add a `deployment/` section. Out of scope here.
- **Out of scope (non-goals)**:
  - Actually creating the nine GitHub repositories (executed by the maintainer post-merge; tracked outside OpenSpec).
  - Per-context business logic, endpoints, or schema migrations.
  - Observability stack, secret management, container registry choice.
  - Any template-system tooling beyond plain text placeholder substitution (no cookiecutter, no copier).
