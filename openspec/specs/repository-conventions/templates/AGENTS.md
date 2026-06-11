# ${CONTEXT_NAME} — Agent Bootstrap

Reference template for the AGENTS.md file every rbrain-* repo MUST ship.
Spec: `openspec/specs/repository-conventions/spec.md` ("AGENTS.md baseline content").
Placeholders use POSIX shell syntax `${VAR}` so the scaffold tool can substitute them.

## Responsibility

${RESPONSIBILITY}

## Non-responsibilities

The following concerns are explicitly NOT owned by `${CONTEXT_NAME}`. If a feature
request lands on this list, route it to the context that owns the concern (see
`openspec/specs/bounded-contexts/catalog.yaml` in `rbrain-codex`).

${NON_RESPONSIBILITIES}

## Owned vocabulary

These terms are defined authoritatively by `${CONTEXT_NAME}`. Other contexts
referring to them SHALL alias rather than redefine.

${OWNED_TERMS}

## Synchronous callers

Contexts that call `${CONTEXT_NAME}` over HTTP. Source of truth:
`openspec/specs/service-topology/sync-graph.yaml` in `rbrain-codex`.

${CALLERS}

## Synchronous callees

Contexts that `${CONTEXT_NAME}` calls over HTTP. Source of truth:
`openspec/specs/service-topology/sync-graph.yaml` in `rbrain-codex`.

${CALLEES}

## Published events (NATS)

NATS JetStream subjects this context publishes. Source of truth:
`OWNERSHIP.yaml.publishes` in this repo; subject naming convention documented
at `openspec/specs/service-topology/nats-naming.md` in `rbrain-codex`.

${PUBLISHES}

## Runtime

This repo's primary runtime is `${RUNTIME}` with a memory budget of
`${MAX_RSS_MB}` MB. Both values are enforced by `scripts/validate-repo.sh`
fetched from `rbrain-codex` at CI run time.

## Extending this file

Sections below this point are optional and SHOULD be added by the repo owner
as needed: local development setup, runbooks, dashboards, on-call notes,
glossary, links to ADRs. Anything above this line is the contract; anything
below is convenience.
