## 1. Spec authorship

- [x] 1.1 Draft ADDED requirement "Health endpoint convention" — uniform GET /health on every HTTP-serving sibling, JSON `{"status":"ok","context":"<name>"}`, no auth, 4 scenarios (cortex smoke, lexicon smoke, codex/deploy out of scope, extra-fields forbidden)
- [x] 1.2 Draft ADDED requirement "<context>-api capabilities include a route-closure clause" — every <context>-api SHALL include a closure clause enumerating public routes and a MODIFIED brake; 4 scenarios (missing-clause rejected, lexicon-api conforms, cortex-api conforms, admin carve-out coexists)
- [x] 1.3 `openspec validate health-and-api-closure-conventions --strict` clean

## 2. Faithfulness audit

- [x] 2.1 Verify `lexicon-api/spec.md` already has the closure clause ("No other HTTP routes at v1") — confirmed via grep
- [x] 2.2 Verify `cortex-api/spec.md` already has the closure clause ("No other public HTTP routes at v1") — confirmed via grep
- [x] 2.3 Verify every HTTP-serving baseline in `scaffold-procedure/baselines/` ships `/health` — confirmed (lexicon, cortex, oracle, forge, gateway, identity, chronicle all carry the route + the smoke curl in their README)
- [x] 2.4 Verify `rbrain-codex` and `rbrain-deploy` declare `runtime: none` so the new health requirement does not apply to them

## 3. CI and archive

- [x] 3.1 Push the 4 planning commits; verify codex CI workflow goes green
- [x] 3.2 Run `/opsx:archive health-and-api-closure-conventions` to promote the ADDED delta into `openspec/specs/repository-conventions/spec.md`
- [x] 3.3 Push the archive commit; verify codex CI stays green
- [x] 3.4 Update the platform handoff drawer in MemPalace
