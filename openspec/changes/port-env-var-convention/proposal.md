## Why

Three commits today shipped the same PORT-env-var pattern (oracle 65238c1, scaffold-template + 8 baselines refresh, lexicon a4a75ec) so that two HTTP-serving siblings don't collide on the same dev host. The pattern is now de facto platform-wide for Rust siblings; ratifying it in `repository-conventions` makes the convention visible to future contributors and to the validators.

The pattern itself was uncovered during the lookup_rule smoke test: oracle hardcoded `0.0.0.0:8080` and crashed when lexicon already held the port. Pre-emptively closing the same dormant collision risk across every HTTP-serving sibling is small and concrete.

## What Changes

- ADD a `Port binding honors a PORT environment variable` requirement in `repository-conventions` specifying that every HTTP-serving `rbrain-*` sibling SHALL parse `PORT` from the environment and bind to it (default 8080) instead of hardcoding the port.
- NO further code changes: scaffold-templates + the existing siblings (lexicon, oracle) already honor the convention. Python (cortex) is out of scope at v1 because uvicorn already accepts `--port` via CLI flag; should a future Python sibling boot uvicorn programmatically, this requirement applies.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `repository-conventions`: ADDED one requirement on the PORT convention. No existing requirement changes.

## Impact

- **Code**: none (already shipped).
- **Specs touched**: `repository-conventions` only.
- **Validators**: a future `validate-port-binding.sh` could iterate scaffold-procedure baselines and grep for `let port`; left as TBD enhancement, not blocked on this change.
- **Migration**: none.
