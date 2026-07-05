## Why

The `deployment-stack` requirement "Health-gated startup ordering" (archived earlier today) mandates an in-container healthcheck probing `GET /health` on **every** service container. That is unimplementable for six of the eight services: the Rust siblings' runtime image is `gcr.io/distroless/cc-debian12`, which ships no shell, no `curl`, no `wget` — a compose `healthcheck.test` has nothing to execute. Only `cortex` (`python:3.12-slim`) and `app` (`node:22-alpine`) can run an in-container probe.

The requirement was written against the intent (health-gated ordering) without checking probe feasibility per image. Distroless is a deliberate, good choice (minimal attack surface, small images) and must not be reverted for the sake of a probe; Kubernetes-side `httpGet` probes (Helm, v2) will cover this properly.

## What Changes

- MODIFY `deployment-stack` "Health-gated startup ordering": infrastructure healthchecks remain mandatory and gate service start; an in-container `GET /health` healthcheck is required only where the service image can execute a probe (`cortex`, `app`); distroless services are exempt from in-container probes, and their health is verified by a host-side `GET /health` sweep once the stack is up (already the settle criterion of the "Single docker compose entry point" requirement).

## Capabilities

### Modified Capabilities

- `deployment-stack`: health-gated ordering made implementable for distroless images.

## Impact

- Contract only; no sibling code. `rbrain-deploy`'s compose implements the corrected requirement directly.
