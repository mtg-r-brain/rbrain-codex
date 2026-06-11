## ADDED Requirements

### Requirement: Scaffold script is a single Bash entry point

`rbrain-codex` SHALL ship a single POSIX Bash script at `scripts/scaffold-repo.sh`. It SHALL be the only supported way to materialize a sibling repository from a template. The script's interface SHALL be:

```
bash scripts/scaffold-repo.sh <context-name> [<target-dir>]
```

- `<context-name>` is mandatory; it SHALL be a valid entry in `bounded-contexts/catalog.yaml`.
- `<target-dir>` is optional; default value is `../rbrain-<context-name>/` relative to the codex repository root.

The script SHALL NOT accept any other arguments, flags, or environment-driven overrides except `--force` (see overwrite requirement below).

#### Scenario: Single-argument invocation

- **WHEN** the maintainer runs `bash scripts/scaffold-repo.sh lexicon`
- **THEN** the script SHALL produce a conformant scaffold at `../rbrain-lexicon/` relative to the codex root

#### Scenario: Unknown context is rejected

- **WHEN** the maintainer runs `bash scripts/scaffold-repo.sh inexistant`
- **THEN** the script SHALL exit non-zero before producing any output, with an error message stating that `inexistant` is not in `catalog.yaml`

### Requirement: Substituted values come exclusively from codex YAML sources

The script SHALL resolve every placeholder value by reading the following authoritative files from `openspec/specs/`:

- `bounded-contexts/catalog.yaml` for `CONTEXT_NAME`, `RESPONSIBILITY`, `NON_RESPONSIBILITIES`, `OWNED_TERMS`
- `service-topology/sync-graph.yaml` for `CALLERS`, `CALLEES`, `PUBLISHES`
- `language-runtimes/runtime-allocation.yaml` for `RUNTIME`
- `language-runtimes/memory-budgets.yaml` for `MAX_RSS_MB`

The script SHALL NOT accept any of these values as command-line arguments, environment variables, or interactive prompts. If any value is missing from its source file, the script SHALL exit non-zero with an error naming the missing field and its source file.

#### Scenario: Missing catalog entry is reported precisely

- **WHEN** `catalog.yaml` lacks a `non_responsibilities` field for the requested context
- **THEN** the script SHALL exit non-zero with an error message naming both the missing field and the source file

#### Scenario: Override via flag is rejected

- **WHEN** the maintainer runs `bash scripts/scaffold-repo.sh lexicon --runtime=python` or sets `RUNTIME=python` in the environment
- **THEN** the script SHALL ignore the override and SHALL use the value from `runtime-allocation.yaml`

### Requirement: Substitution uses envsubst with an explicit allowlist

The script SHALL invoke `envsubst` with an explicit list of allowed placeholders (matching the set defined by `scaffold-templates`'s placeholder requirement). Tokens outside that allowlist appearing in template files SHALL pass through unchanged.

#### Scenario: $HOME in a template file passes through

- **WHEN** a template file contains the literal string `${HOME}` (e.g. inside a script snippet)
- **THEN** the scaffolded output SHALL contain the unchanged string `${HOME}`, not the maintainer's home directory path

### Requirement: List-typed values are pre-expanded into bullet form

Before invoking `envsubst`, the script SHALL pre-expand every list-typed value (`NON_RESPONSIBILITIES`, `OWNED_TERMS`, `CALLERS`, `CALLEES`, `PUBLISHES`) into a newline-delimited string where each line is prefixed with `- `. The pre-expansion SHALL be performed via `yq -r '.<path>[]'` and a shell loop that prepends `- ` to each element.

#### Scenario: Bullet list rendering

- **WHEN** `catalog.yaml` declares `non_responsibilities: [card-search, deck-management]` for `oracle`
- **THEN** the substituted `${NON_RESPONSIBILITIES}` value SHALL be the two-line string `"- card-search\n- deck-management"` and SHALL appear as a Markdown bullet list in the scaffolded `AGENTS.md`

#### Scenario: Empty list handling

- **WHEN** a list field is an empty array `[]`
- **THEN** the substituted value SHALL be an empty string (no bullet lines), and the surrounding template text SHALL render coherently (e.g. an explicit "(none)" placeholder in `AGENTS.md` if appropriate)

### Requirement: Script refuses to overwrite a non-empty target without --force

If `<target-dir>` exists and is non-empty, the script SHALL exit non-zero with an error and SHALL NOT write any file, unless the maintainer passes `--force` as a third argument. With `--force`, the script SHALL overwrite existing files but SHALL NOT delete files that the template does not write.

#### Scenario: Non-empty target is protected

- **WHEN** the maintainer runs `bash scripts/scaffold-repo.sh lexicon ../rbrain-lexicon` and `../rbrain-lexicon/` already contains files
- **THEN** the script SHALL exit non-zero with an error explaining that `--force` is required to overwrite

#### Scenario: --force preserves non-template files

- **WHEN** the maintainer runs the scaffold with `--force` on a directory containing both template-managed files (e.g. `OWNERSHIP.yaml`) and unrelated files (e.g. a custom `notes.md`)
- **THEN** the template-managed files SHALL be overwritten and the unrelated files SHALL be left untouched

### Requirement: Script validates the scaffolded output before exiting

After writing the scaffolded files, the script SHALL invoke `scripts/validate-repo.sh` against the target directory. If validation fails, the script SHALL exit non-zero, propagating the validator's error output, but SHALL NOT roll back the written files.

#### Scenario: Validation success path

- **WHEN** the scaffold produces a conformant repository
- **THEN** the script SHALL invoke `validate-repo.sh` against the target, report success, and exit zero

#### Scenario: Validation failure leaves output in place for inspection

- **WHEN** validation fails (e.g. because a YAML source was inconsistent with the templates)
- **THEN** the script SHALL exit non-zero, the maintainer SHALL be able to inspect the partial output, and the resolution SHALL be to fix the YAML source and re-run with `--force`

### Requirement: Post-scaffold checklist is documented

`rbrain-codex` SHALL ship a human-facing checklist at `openspec/specs/scaffold-procedure/checklist.md` enumerating the steps the maintainer performs after a successful scaffold:

- create the GitHub repository named `rbrain-<context>`
- push the initial commit
- enable Actions, branch protection on `main`, and required CI checks
- add the repository to `rbrain-deploy`'s discovery list (when that repo exists)
- announce in the project's Discord (when applicable)

The checklist SHALL be referenced from the scaffold script's success output.

#### Scenario: Maintainer follows the checklist

- **WHEN** a scaffold completes successfully
- **THEN** the script's final output SHALL print a one-line pointer to `openspec/specs/scaffold-procedure/checklist.md`

### Requirement: Drift detection job runs in codex CI

`rbrain-codex`'s CI SHALL include a job named `scaffold-drift` that, for every context whose `runtime` is not `none`, dry-runs the scaffold script against a temporary directory and compares the resulting tree against a recorded baseline (e.g. a checked-in `.scaffold-baseline-<context>/` directory or a hash committed to codex). The job SHALL fail if the dry-run output diverges from the baseline, signalling that templates or YAML sources have evolved without the baseline being refreshed.

#### Scenario: Template change without baseline refresh is caught

- **WHEN** a contributor edits `rust-service/AGENTS.md` template but does not update the baseline
- **THEN** the `scaffold-drift` job SHALL fail with a diff pointing at the changed file

#### Scenario: Baseline refresh is part of any template-affecting change

- **WHEN** a contributor edits any template or YAML source
- **THEN** they SHALL also update the recorded baselines in the same commit, and the CI job SHALL then pass
