## 1. Convention

- [ ] 1.1 ADD `repository-conventions` requirement "Archiving an OpenSpec change is staged with `git add -A`".
- [ ] 1.2 `openspec validate archive-staging-convention --strict` passes.

## 2. Friction follow-up

- [ ] 2.1 Update the `harness-friction` Finding-C tag with the corrected root cause (skill uses `mv`, not `cp`; the gap is git staging; skill is auto-generated so the durable fix is this convention + upstream openspec feedback).

## 3. CI + archive

- [ ] 3.1 Push planning commit.
- [ ] 3.2 Archive with `openspec archive` + `git add -A openspec/` (dogfooding the convention); promote canonical `repository-conventions`.
- [ ] 3.3 Push the archive commit.
