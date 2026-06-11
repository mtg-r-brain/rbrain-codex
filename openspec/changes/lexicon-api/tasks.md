## 1. Documentation alignment

- [x] 1.1 Update `rbrain-codex/README.md`'s entry-point table to add a row pointing newcomers at `openspec/specs/lexicon-api/spec.md` as the authoritative HTTP contract for `rbrain-lexicon`.
- [x] 1.2 Add a short note in `rbrain-codex/AGENTS.md`'s working conventions documenting the per-sibling `<context>-api` capability naming pattern so future siblings follow it.

## 2. Hand-off

- [x] 2.1 Commit, push, and confirm CI on `rbrain-codex` stays green (the spec-only change touches no validators).
- [x] 2.2 Archive this change via `openspec archive lexicon-api`. No script and no validator land — the spec moves into `openspec/specs/lexicon-api/` as the live contract.
- [ ] 2.3 Open a follow-up task in `rbrain-cortex` (when that sibling starts) to wire the `lookup_card` agent tool against this spec; tracked here for traceability only.
- [ ] 2.4 When `rbrain-lexicon` ships its next public endpoint (search, list, etc.), the implementer SHALL open a MODIFIED delta against `lexicon-api` in the same PR; document this expectation in the slice's own change proposal rather than enforcing it here.
