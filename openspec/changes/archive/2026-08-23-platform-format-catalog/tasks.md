# Tasks — platform-format-catalog

## 1. Verify before documenting

- [x] Confirm the two Rust constants are rustfmt one-string-per-line (`lexicon src/legality.rs`, `forge src/legality_store.rs`) so the extraction shape holds
- [x] Confirm lexicon and forge CI already check out rbrain-codex at `.codex` and run `validate-repo.sh` (the sibling-mode wiring point exists)
- [x] Confirm `sixteen` appears in codex only in `forge-api/spec.md` (lines covered by the MODIFIED delta) so no count word survives elsewhere

## 2. Codex artifacts (feat)

- [x] `openspec/specs/format-catalog/formats.yaml` — the sixteen ADR-0003 formats
- [x] `scripts/validate-formats.sh` — self mode + sibling mode per design.md
- [x] `.github/workflows/ci.yml` — `Validate format catalog` step in the validate job

## 3. Apply the deltas (sync)

- [x] Both MODIFIED requirement headers match the canonical spec verbatim
- [x] `openspec archive platform-format-catalog -y`
- [x] Verify the promoted specs: `format-catalog/spec.md` created; `forge-api/spec.md` carries the catalog provenance sentence and zero `sixteen` count words; identifiers unchanged
- [x] `bash scripts/validate-formats.sh` green (self mode — only meaningful after promotion, see design.md ordering note)
- [x] `bash scripts/validate-formats.sh ../rbrain-lexicon` and `../rbrain-forge` green
- [x] `bash scripts/validate-repo.sh .` and `bash scripts/validate-api-closure.sh` still green
- [x] Stage the sync commit with an explicit path list (`openspec/specs/format-catalog/spec.md`, `openspec/specs/forge-api/spec.md`) — never `git add -A openspec/`

## 4. Sibling wiring (chore commits, no OpenSpec change)

- [ ] lexicon: CI step `bash .codex/scripts/validate-formats.sh .` after validate-repo; `FORMATS` doc comment points at the catalog; `cargo fmt --check` + `cargo clippy` green
- [ ] forge: same
- [ ] Push all three repos; confirm the three CI runs green
