## 1. bounded-contexts capability

- [x] 1.1 Create `openspec/specs/bounded-contexts/catalog.yaml` with the ten entries (`gateway`, `identity`, `lexicon`, `oracle`, `forge`, `cortex`, `chronicle`, `app`, `deploy`, `codex`), each with `responsibility`, `non_responsibilities`, and `owned_terms` populated from `ideas/02-repositories.md` and the design rationale.
- [x] 1.2 Draft the initial `owned_terms` list per context (e.g., `lexicon`: card, set, printing; `forge`: deck, deck-list, format-legality; `oracle`: rule, ruling, comprehensive-rules) and verify uniqueness across the catalog.
- [x] 1.3 Write a `scripts/validate-catalog.sh` (or equivalent) that loads `catalog.yaml`, asserts exactly ten entries, asserts no duplicate `owned_terms` across contexts, and asserts each repo-name matches `rbrain-<context>`.
- [ ] 1.4 Wire the catalog validation into `rbrain-codex` CI so any modification to `catalog.yaml` is checked on push.

## 2. service-topology capability

- [x] 2.1 Create `openspec/specs/service-topology/sync-graph.yaml` enumerating the seven initial edges (`app→gateway`, `gateway→identity`, `gateway→cortex`, `gateway→chronicle`, `cortex→lexicon`, `cortex→oracle`, `cortex→forge`) with a `purpose` field per edge.
- [x] 2.2 Extend `scripts/validate-catalog.sh` (or add `scripts/validate-topology.sh`) to assert the sync graph is a DAG and every node referenced is a valid catalog entry.
- [x] 2.3 Document the NATS subject naming convention `rbrain.<ctx>.<event-name>` in a short `openspec/specs/service-topology/nats-naming.md` reference, with concrete examples derived from the foreseeable event surface.
- [ ] 2.4 Add a CI check that any subject pattern declared in any future `OWNERSHIP.yaml.publishes` matches the convention regex.

## 3. repository-conventions capability

- [x] 3.1 Create `openspec/specs/repository-conventions/templates/OWNERSHIP.yaml` as the reference template, with inline comments documenting each of the five fields (`context`, `owner`, `runtime`, `depends_on`, `publishes`).
- [x] 3.2 Create `openspec/specs/repository-conventions/templates/AGENTS.md` as the baseline content template (placeholders for context name, responsibility, non-responsibilities, callers/callees, published subjects).
- [x] 3.3 Write `scripts/validate-repo.sh` that, given a path to an `rbrain-*` repo, asserts presence of the four mandatory files and validates `OWNERSHIP.yaml` against the schema (5 required fields, allowed runtimes, depends_on subset of `sync-graph.yaml` edges originating from this context, publishes patterns match `rbrain.<ctx>.<event>`).
- [ ] 3.4 Document in `rbrain-codex`'s own `AGENTS.md` how to invoke the validators locally and in CI, so contributors discover them without reading every spec.

## 4. Hand-off

- [ ] 4.1 Update `rbrain-codex/README.md` to point newcomers at `openspec/specs/bounded-contexts/catalog.yaml` as the entry point to the platform.
- [ ] 4.2 Open a follow-up OpenSpec change `scaffold-sibling-repos` whose scope is the creation of the nine sibling repositories against these conventions; this change does not perform that scaffolding itself.
- [ ] 4.3 Archive this change via `openspec archive platform-architecture` once tasks 1.x–3.x are complete and CI is green.
