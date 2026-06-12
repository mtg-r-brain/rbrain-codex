## Context

The platform's `repository-conventions` capability defines four requirements today: mandatory root files, OWNERSHIP.yaml schema, AGENTS.md baseline, and "internal layout is not prescribed". Notably absent: any normative description of the HTTP smoke surface every sibling exposes, and any rule on how `<context>-api` capabilities should close their public route sets.

Both conventions exist as habit:

- `/health` is hardcoded into every `scaffold-procedure` baseline template (`rbrain-cortex/app/main.py`, `rbrain-lexicon/src/main.rs`, etc.). The smoke curls in every README test against it. cortex-api and lexicon-api both reference it as "defined by repository-conventions" — a forward reference that, until now, pointed nowhere.

- The closure clause was invented for lexicon-api ("No other HTTP routes at v1"), then replicated verbatim into cortex-api ("No other public HTTP routes at v1") on 2026-06-12. The text is nearly identical; the intent is the brake that forces every new public route through OpenSpec review.

Both deserve to live as normative requirements:

- `/health` because the implicit expectation is real — any future sibling shipping HTTP without it would break operator runbooks, kube probes, gateway health checks.
- The closure clause because the next four siblings (gateway, oracle, identity, forge, chronicle) will each get their own `<context>-api` capability; without the rule written down, a future contributor could ship one without the clause.

## Goals / Non-Goals

**Goals:**

- Ratify `GET /health` as a platform-wide HTTP-serving sibling contract: response shape, status, no auth, no path/query parameters.
- Ratify the closure-clause convention so every `<context>-api` capability MUST include a normative requirement enumerating the public route set with a MODIFIED brake on additions.
- Make the lexicon-api/cortex-api cross-references to "repository-conventions" valid (today they reference a requirement that doesn't yet exist).
- Stay descriptive: zero code changes, zero spec updates to capabilities other than `repository-conventions`.

**Non-Goals:**

- Specifying `/health`'s payload beyond status + context. A future enhancement might add a `version`, `git_sha`, `dependencies` map; out of scope here.
- Specifying readiness vs liveness probes (Kubernetes-style `/healthz` + `/readyz`). The platform uses one `/health` per sibling today; splitting is a separate change when ops needs surface.
- Building a `validate-context-api-closure.sh` codex script. The closure rule is enforceable by reviewers; a script can land as a follow-up if drift becomes real.
- Backfilling the `/health` requirement into runtime ports per sibling. Every HTTP-serving sibling already exposes it; the new requirement just makes the de facto contract de jure.
- Carving out `/health` from auth in identity / gateway. When identity ships, the convention says `/health` is unauthenticated; if a sibling needs auth on its health endpoint, that's a MODIFIED on this convention.

## Decisions

### Decision 1: `/health` requirement scopes to "HTTP-serving siblings" — codex and deploy are excluded

**Choice:** The requirement applies to every `rbrain-*` sibling whose `OWNERSHIP.runtime` is not `none`. `rbrain-codex` and `rbrain-deploy` (runtime = `none`, no HTTP surface) are explicitly out of scope.

**Rationale:** The platform already has the runtime-vs-none distinction baked into `language-runtimes`. Reusing it keeps the requirement single-source.

### Decision 2: Uniform response shape — `{"status":"ok","context":"<name>"}` exactly

**Choice:** The response body SHALL be a JSON object with exactly two string fields: `status` (literal `"ok"`) and `context` (the bounded context name matching `OWNERSHIP.yaml.context`). Status code `200`. Content-Type `application/json`. No auth. No path/query parameters.

**Rationale:** Three benefits:

1. **One-line smoke test.** Every sibling's README shows `curl http://host/health` returning the same shape minus the context name. A consistent shape means operators don't have to read per-sibling docs for the health probe semantics.
2. **Pattern matches what every baseline already ships.** Zero migration burden.
3. **Bounded.** Adding a `version`, `git_sha`, `uptime_seconds`, or `dependencies` map is tempting but pre-emptive. Each addition is a MODIFIED change with its own design discussion.

**Alternatives considered:**

- **JSON `null` body or empty body**: rejected. Loses the `context` discriminator that's useful in fan-out probes.
- **Per-sibling shape**: rejected. Defeats the convention.
- **Include `version` and `git_sha`**: deferred. Useful but tangential; ship when a real consumer asks.

### Decision 3: Closure clause requires a normative requirement in each `<context>-api` capability, not just a recommendation

**Choice:** Every codex capability whose name matches the `<context>-api` pattern SHALL include a requirement whose body enumerates the public route set and states that additions require a MODIFIED delta on that capability. The requirement may carve out `/admin/*` separately (lexicon-api-admin-carveout precedent) but the closure clause SHALL exist.

**Rationale:** Optional conventions are conventions until they aren't. A normative "SHALL include" rule makes drift visible at review time. The pattern is already battle-tested on lexicon-api (extended once via lexicon-api-admin-carveout) and cortex-api (will extend when admin endpoints surface).

**Alternatives considered:**

- **"SHOULD include"**: rejected. SHOULD-only conventions decay. The closure clause is the platform's only brake on accidental public-API growth.
- **Centralised registry of public routes in repository-conventions**: rejected. Each capability owns its own routes; a central registry would duplicate without adding enforcement.
- **Codex validator script (`scripts/validate-api-closure.sh`)**: deferred. A reviewer-enforced rule is sufficient at v1; a script is a follow-up if drift becomes real.

### Decision 4: `<context>-api` naming convention is implicit, not separately defined

**Choice:** The closure-clause requirement references "capabilities matching the `<context>-api` naming pattern" without defining a separate naming-convention requirement. The pattern is observable from existing capabilities (`lexicon-api`, `cortex-api`) and reviewers know it.

**Rationale:** Adding a "capabilities SHALL follow `<context>-api` naming" requirement would be a meta-rule with no enforcement and no observable risk. Defer until a sibling actually misnames its API capability (it hasn't happened in 3 archived capabilities).

## Risks / Trade-offs

- **[Risk] A future sibling claims its HTTP surface is "operator-only" and tries to skip `/health`** → Mitigation: the requirement scope (`runtime != "none"`) catches this. An operator-only sibling either declares `runtime: none` (and doesn't serve HTTP) or accepts the convention.

- **[Trade-off] Specifying `/health` to be unauthenticated forecloses an "internal-only health probe" design** → Accepted. If a sibling wants authenticated health checks, that's a MODIFIED on this convention. The default (unauthenticated, internal-network-only by network policy) matches every cloud platform's probe convention.

- **[Risk] The closure clause forces every new sibling to plan its public surface up-front** → Accepted as a feature, not a bug. The whole point is to make adding routes slow on purpose.

- **[Trade-off] No codex validator script for the closure clause** → Accepted. Adding one is straightforward (iterate `openspec/specs/*-api/spec.md`, grep for "No other public" or similar). Defer until a closure-skip happens in review.

## Open Questions

None. Both conventions are observed today; the change ratifies them.
