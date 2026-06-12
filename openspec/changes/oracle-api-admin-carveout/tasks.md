## 1. Spec authorship

- [x] 1.1 Draft MODIFIED requirement with the same carve-out paragraphs as lexicon-api-admin-carveout, retargeted to oracle
- [x] 1.2 Drop the v1 "SHALL NOT expose any /admin/*" prohibition; add the gateway-rejection clause
- [x] 1.3 4 scenarios: new public endpoint goes through OpenSpec, /health out of scope, admin doesn't need codex change, gateway rejects external admin traffic
- [x] 1.4 `openspec validate oracle-api-admin-carveout --strict` clean

## 2. CI and archive

- [ ] 2.1 Push the 4 planning commits; verify codex CI workflow goes green (validate-api-closure.sh SHALL still pass — the canonical closure phrasing is intact)
- [ ] 2.2 Run `/opsx:archive oracle-api-admin-carveout` to promote the MODIFIED delta into `openspec/specs/oracle-api/spec.md`
- [ ] 2.3 Push the archive commit; verify codex CI stays green

## 3. Unblocks

- [ ] 3.1 Once archived, the rbrain-oracle `comprehensive-rules-sync` change ships POST /admin/sync without further codex changes
