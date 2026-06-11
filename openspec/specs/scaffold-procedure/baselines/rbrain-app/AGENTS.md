# app — Agent Bootstrap

Conformant to the AGENTS.md baseline defined in `openspec/specs/repository-conventions/spec.md` in `rbrain-codex`.

## Responsibility

Renders the user-facing Next.js application — chat UI, deck builder, blog reader.

## Non-responsibilities

- backend business logic
- direct database access
- LLM provider calls

## Owned vocabulary

- page
- viewport
- session-cookie
- ui-state

## Synchronous callers

(none)

## Synchronous callees

- gateway

## Published events (NATS)

(none)

## Runtime

This repo runs on `typescript` (Node.js >= 22) with a memory budget of `100` MB. CI enforces both via `validate-repo.sh` fetched from `rbrain-codex` `main`.

## Working in this repo

### Stack

- Next.js 15 with the App Router and React Server Components
- React 18, TypeScript 5.6
- `pnpm` for dependencies — never use `npm install` directly
- ESLint (`next/core-web-vitals`) + Prettier

### Build, test, run

```sh
pnpm install --frozen-lockfile
pnpm dev
pnpm build
pnpm tsc:check
pnpm lint
pnpm format:check
```

### Memory ceiling

Memory headroom is tight (`100` MB total RSS for the SSR runtime). Streaming and RSC keep most work off the Node process; any change that introduces heavyweight server-side bundles should be benchmarked.

### Conventions

- English everywhere (commits, PRs, docs, code, JSX text).
- Gitmoji commits.
- ESLint and Prettier enforced — `pnpm format:check` and `pnpm lint` MUST pass.
- No `console.log` in production paths (the rule is enforced by ESLint).
