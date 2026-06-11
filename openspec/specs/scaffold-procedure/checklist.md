# Scaffold checklist

Reference document. The normative requirement lives in
`openspec/specs/scaffold-procedure/spec.md` ("Post-scaffold checklist
is documented").

After a successful `scripts/scaffold-repo.sh <context>` invocation, the
maintainer SHOULD perform the steps below to bring the new sibling
repository online. The scaffold script's final output points here.

## 1. Inspect the scaffolded tree

```sh
cd ../rbrain-<context>
ls -la
cat OWNERSHIP.yaml
```

Confirm:

- `context`, `runtime`, `max_rss_mb` match the catalog.
- `depends_on` matches the sync graph callees.
- Mandatory files present (`README.md`, `AGENTS.md`, `OWNERSHIP.yaml`,
  `.github/workflows/ci.yml`).

The script already runs `validate-repo.sh` against the output; a green
exit means the contract is honored at this point.

## 2. Initialize the git repository

```sh
cd ../rbrain-<context>
git init
git add .
git commit -m "✨ init: scaffold rbrain-<context> from rbrain-codex template"
```

Use Gitmoji + English per the platform convention.

## 3. Create the GitHub repository

Through the GitHub UI or `gh`:

```sh
gh repo create mtg-r-brain/rbrain-<context> \
  --private \
  --description "$(yq -r .responsibility ../rbrain-codex/openspec/specs/bounded-contexts/catalog.yaml | yq ".contexts.<context>.responsibility")" \
  --source . \
  --remote origin
```

Or manually:

```sh
git remote add origin git@github.com:mtg-r-brain/rbrain-<context>.git
git push -u origin main
```

## 4. Enable Actions and branch protection

Either via the GitHub UI:

- Settings → Actions → General → Allow all actions
- Settings → Branches → Add rule for `main`:
  - Require pull request before merging
  - Require status checks to pass: `Build & validate`
  - Require linear history

Or via `gh` API:

```sh
gh api -X PUT \
  repos/mtg-r-brain/rbrain-<context>/actions/permissions \
  -f enabled=true -f allowed_actions=all
```

(branch protection requires a JSON body — see `gh api --help`)

## 5. First CI run

The first push triggers CI. Confirm green:

```sh
gh run watch --repo mtg-r-brain/rbrain-<context>
```

If `Fetch and run validate-repo` fails, it almost always means a YAML
source in `rbrain-codex` is inconsistent with the scaffolded
`OWNERSHIP.yaml`. Fix the YAML in `rbrain-codex`, push, then re-run CI
on the sibling.

## 6. Add to deployment discovery (once `rbrain-deploy` exists)

`rbrain-deploy` will discover services by reading every `OWNERSHIP.yaml`
across siblings. Until that capability is shipped, this step is a TODO.

## 7. Announce (optional)

If a community Discord channel exists, post a one-liner with the repo
link. Skip for the first runs while the platform is still bootstrapping.

## Re-scaffolding

If the templates evolve in `rbrain-codex` and a sibling needs to absorb
the change, re-run with `--force` from inside the sibling repo's
parent:

```sh
bash ../rbrain-codex/scripts/scaffold-repo.sh <context> ./rbrain-<context> --force
git diff
```

The `--force` flag overwrites template-managed files; unrelated files
(notes, custom Dockerfile additions outside the template, generated
artefacts) are left untouched.
