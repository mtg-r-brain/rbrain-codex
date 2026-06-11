# rbrain-app

Renders the user-facing Next.js application — chat UI, deck builder, blog reader.

Part of the [MTG R.brain](https://github.com/mtg-r-brain) platform. The contract this repo honors lives in [`rbrain-codex`](https://github.com/mtg-r-brain/rbrain-codex). See `AGENTS.md` for the bootstrap.

## Stack

- **Runtime**: typescript (Node.js >= 22)
- **Memory budget**: 100 MB
- **Framework**: Next.js 15 (App Router, RSC)
- **Package manager**: [`pnpm`](https://pnpm.io/)

## Local development

```sh
pnpm install --frozen-lockfile
pnpm dev                    # Next.js dev server
pnpm start                  # production server on :8080
```

## Quality gates

```sh
pnpm tsc:check
pnpm lint
pnpm format:check
bash <(curl -fsSL https://raw.githubusercontent.com/mtg-r-brain/rbrain-codex/main/scripts/validate-repo.sh) .
```

CI runs all of the above on every push and PR.
