## 1. Spec authorship

- [x] 1.1 Draft ADDED requirement "Port binding honors a PORT environment variable" — silent fallback to 8080, scoped to runtime!=none, Python siblings may use uvicorn --port.
- [x] 1.2 Four scenarios: default 8080, override honored, unparseable falls back silently, codex/deploy out of scope.
- [x] 1.3 `openspec validate port-env-var-convention --strict` clean.

## 2. Faithfulness audit (no new code)

- [x] 2.1 Verify the convention is already implemented in `scaffold-templates/templates/rust-service/src/main.rs` (this session's `ce0e569`).
- [x] 2.2 Verify the convention is shipped on lexicon's main.rs (`a4a75ec`) and oracle's main.rs (`65238c1`).
- [x] 2.3 Verify all 6 Rust baselines under scaffold-procedure carry the pattern (refresh-baselines.sh propagated it in `ce0e569`).

## 3. CI and archive

- [ ] 3.1 Push the 4 planning commits; verify codex CI workflow goes green.
- [ ] 3.2 Run `/opsx:archive port-env-var-convention` to promote the ADDED delta into `openspec/specs/repository-conventions/spec.md`.
- [ ] 3.3 Push the archive commit; verify codex CI stays green.
