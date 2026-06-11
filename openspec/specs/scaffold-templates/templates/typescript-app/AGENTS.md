# ${CONTEXT_NAME} — Agent Bootstrap

Conformant to the AGENTS.md baseline defined in `openspec/specs/repository-conventions/spec.md` in `rbrain-codex`.

## Responsibility

${RESPONSIBILITY}

## Non-responsibilities

${NON_RESPONSIBILITIES}

## Owned vocabulary

${OWNED_TERMS}

## Synchronous callers

${CALLERS}

## Synchronous callees

${CALLEES}

## Published events (NATS)

${PUBLISHES}

## Runtime

This repo runs on `${RUNTIME}` (Node.js >= 22) with a memory budget of `${MAX_RSS_MB}` MB. CI enforces both via `validate-repo.sh` fetched from `rbrain-codex` `main`.

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

Memory headroom is tight (`${MAX_RSS_MB}` MB total RSS for the SSR runtime). Streaming and RSC keep most work off the Node process; any change that introduces heavyweight server-side bundles should be benchmarked.

### Conventions

- English everywhere (commits, PRs, docs, code, JSX text).
- Gitmoji commits.
- ESLint and Prettier enforced — `pnpm format:check` and `pnpm lint` MUST pass.
- No `console.log` in production paths (the rule is enforced by ESLint).
