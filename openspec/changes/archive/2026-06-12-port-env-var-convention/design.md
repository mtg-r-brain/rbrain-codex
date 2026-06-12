## Context

The pattern is mechanical: read `PORT` from the env, parse it as `u16`, default to 8080 if absent or unparseable. The pragmatic argument for it is the dev story — running two HTTP siblings on the same laptop without picking a port collision war. The architectural argument is operability: every PaaS-style runner sets `PORT` automatically, and hardcoding kills that ergonomics.

This change ratifies what's already in code. No new design work.

## Goals / Non-Goals

**Goals:**

- Make the PORT convention discoverable in `repository-conventions` so future contributors find it before they hardcode 8080.
- Keep the default at 8080 so existing deploys and READMEs continue to work.
- Scope to HTTP-serving siblings so codex/deploy (runtime=none) are explicitly out of scope.

**Non-Goals:**

- A blanket "no hardcoded ports anywhere" rule. The Dockerfile's `EXPOSE 8080` is fine — it's a hint, not a binding.
- Forcing a specific port allocation per BC. Each operator picks; the convention only requires the override mechanism to exist.
- A codex validator script. Reviewer-enforced is fine at v1.

## Decisions

### Decision 1: Default to 8080 on missing or unparseable PORT

**Choice:** `env::var("PORT").ok().and_then(|s| s.parse().ok()).unwrap_or(8080)`. Both "PORT unset" and "PORT='abc'" silently fall back to 8080.

**Rationale:** Silent fallback matches PaaS conventions (Heroku, Cloud Run, Railway). A typo in PORT shouldn't crash the boot — it should boot on 8080 with a log line for ops to notice.

**Alternatives considered:**

- **Fail fast on unparseable PORT**: rejected. Matches EX_CONFIG discipline for DATABASE_URL et al., but the operability cost (one typo and the pod doesn't come up) exceeds the safety benefit.
- **Default to a different per-BC port**: rejected. 8080 is the platform-wide default; per-BC dev overrides happen via `PORT=8082 cargo run`.

### Decision 2: Convention applies to HTTP-serving siblings only

**Choice:** Scope by `OWNERSHIP.runtime != none` (same gate as the `/health` convention). codex + deploy are out of scope.

**Rationale:** Aligns with the existing scoping pattern in `repository-conventions` "Health endpoint convention". Single source of truth for "what makes a sibling HTTP-serving".

## Risks / Trade-offs

- **[Risk] An operator sets PORT to a privileged port (< 1024) and the bind fails** → Accepted. That's an operator error surfaced loudly at boot via the `bind` panic message. The convention isn't a magic shield against `PORT=80`.

- **[Trade-off] Silent fallback on garbage PORT means a typo lingers** → Accepted. Logged but not fatal. Better than a deploy-time crash loop.

## Open Questions

None.
