## Why

Two cross-context conventions exist *de facto* on the platform but are not normatively ratified:

1. **Every HTTP-serving sibling exposes `GET /health`** with a uniform `{"status":"ok","context":"<name>"}` shape. Every scaffold-procedure baseline implements it (lexicon, cortex, oracle, forge, gateway, identity, chronicle); the smoke curls in their READMEs assume it; cortex-api and lexicon-api both reference `GET /health` as "defined by repository-conventions" — but no such requirement actually exists in `repository-conventions/spec.md`. The cross-spec reference is currently a lie of omission.

2. **Every `<context>-api` capability declares a route-closure clause** ("No other public HTTP routes at v1"). lexicon-api has it (since 2026-05-01); cortex-api has it (archived 2026-06-12). The pattern is the brake that forces any new public route through OpenSpec review — but it lives by precedent, not by rule. Future `<context>-api` capabilities (gateway-api, identity-api, oracle-api, forge-api, chronicle-api) could ship without the clause and the platform would lose the brake.

Both gaps are small, both are obvious in retrospect, and the next batch of siblings (ticket #5 territory: identity / oracle / forge) will compound the problem if they ship without these conventions ratified.

## What Changes

- ADD a `Health endpoint convention` requirement in `repository-conventions` specifying that every HTTP-serving `rbrain-*` sibling exposes `GET /health` with the uniform response shape, no auth, no path parameters; codex and deploy are out of scope (runtime = `none`).
- ADD an `<context>-api capabilities must include a route-closure clause` requirement in `repository-conventions` specifying that every codex capability matching the `<context>-api` naming convention SHALL include a normative requirement whose body enumerates the closed public route set with a MODIFIED-required clause for any addition.
- NO updates to existing capabilities. lexicon-api and cortex-api both already satisfy the new requirements; their pre-existing "defined by repository-conventions" cross-references now resolve to real requirements.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `repository-conventions`: ADDED two requirements — health endpoint contract + `<context>-api` closure-clause mandate. No existing requirement is modified or removed.

## Impact

- **Code**: none. Every HTTP-serving sibling already ships `/health`; lexicon-api and cortex-api already carry the closure clause.
- **Specs touched**: `repository-conventions` only.
- **Validators**: no immediate code change. A future `validate-context-api-closure.sh` could iterate `openspec/specs/*-api/spec.md` and check for a closure-shaped requirement; left as a TBD enhancement, NOT blocked on this change.
- **Migration**: none — both conventions already hold across the platform.
- **Cross-spec references**: lexicon-api/cortex-api's "defined by `repository-conventions`" hyperlinks for `/health` become valid after this change.
