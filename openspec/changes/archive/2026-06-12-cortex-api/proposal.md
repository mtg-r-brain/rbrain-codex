## Why

`rbrain-cortex` ships its public HTTP surface today (`POST /chat`) but no codex-side capability anchors the contract. Every other public-facing sibling has one: `lexicon-api` for lexicon, scaffolded slots for gateway/identity/oracle/forge/chronicle/app to come. Without `cortex-api`, three problems compound:

1. **No cross-context source of truth.** A future `rbrain-gateway` slice has no spec to validate its outbound proxy against. It would have to read cortex's implementation code to know the wire shape — the same anti-pattern lexicon-api was created to solve.
2. **No closure clause.** Cortex could grow a public route (`POST /completions`, `GET /conversations/{id}`, batch endpoints) without a codex review. The lexicon-api "No other public routes" requirement is the gate that prevents accidental API drift; cortex needs the same.
3. **No place to ratify the `finish_reason` discipline.** Cortex exposes `finish_reason` as opaque provider passthrough today plus the cortex-injected `"budget_exhausted"`. That semantic — reserved literal plus opaque rest — needs to live somewhere normative before clients (gateway, future SDKs) build assumptions on it.

This change creates `cortex-api` to mirror what `lexicon-api` does for the lexicon BC. Zero code changes in cortex — the spec describes what's already there.

## What Changes

- ADD a new `cortex-api` capability in `rbrain-codex/openspec/specs/cortex-api/spec.md` with five requirements:
  1. `rbrain-cortex` exposes `POST /chat` (route + caller via the `gateway → cortex` edge)
  2. `POST /chat` request body shape (`message`, `conversation_id?`)
  3. `POST /chat` response body shape (`response`, `conversation_id`, `tool_calls`, `finish_reason` with reserved/opaque discipline)
  4. `tool_calls` trace entry shape (`tool`, `args`, `observation`)
  5. No other public HTTP routes at v1 (carve-out for `GET /health` already mandated by `repository-conventions`)
- NO existing codex capability changes:
  - `service-topology/sync-graph.yaml` already carries the `gateway → cortex` edge
  - `bounded-contexts/catalog.yaml` already lists `cortex`
  - `repository-conventions` already mandates `GET /health` on every sibling
  - `llm-abstraction` and `data-stores` are unrelated to the public API surface

## Capabilities

### New Capabilities

- `cortex-api`: the external HTTP contract `rbrain-cortex` exposes. Owns the `POST /chat` request/response shapes, the `tool_calls` trace shape, the `finish_reason` discipline, and the closure clause on the public route set.

### Modified Capabilities

(none)

## Impact

- **Code**: none. The spec captures behavior cortex already serves end-to-end as of 2026-06-11 (slice 1 archived) and 2026-06-12 (`search_cards` tool ADDED to `cortex-bootstrap`).
- **APIs**: no wire change. The change is descriptive.
- **Dependencies**: none.
- **Specs touched**: codex only. The companion implementation spec at `rbrain-cortex/openspec/specs/cortex-bootstrap/spec.md` already mandates the matching internal behavior; `cortex-api` is its external mirror.
- **Validators**: the existing 7 codex validators (catalog, topology, runtimes, data-stores, subjects, llm-config, repo) do not need adjustment — `cortex-api` becomes the 11th capability in `openspec/specs/` but no validator iterates over the public route set (yet).
- **Migration**: none.
- **Cortex CI**: unaffected — cortex's source tree is untouched.
