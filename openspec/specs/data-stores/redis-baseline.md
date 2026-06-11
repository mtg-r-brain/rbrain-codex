# Redis baseline policy

Reference document. The normative requirement lives in
`openspec/specs/data-stores/spec.md` ("Redis is the sole cache layer").

## What Redis is for

A **shared cache**. Three use cases at v1:

- **Session storage** — `rbrain-identity` stores active sessions keyed by JWT
  id.
- **External API response cache** — `rbrain-lexicon` caches Scryfall lookups to
  avoid hammering the upstream API.
- **Rate-limit counters** — `rbrain-gateway` keeps rolling-window counters per
  user / IP.

Anything else needs an OpenSpec change.

## What Redis is NOT for

- **Not a primary datastore.** Data that must survive a cache flush or
  instance restart lives in PostgreSQL. Redis is configured without AOF
  persistence and with RDB snapshots disabled for the cache instance.
- **Not an event bus.** Cross-context notifications go through NATS JetStream
  (see `openspec/specs/messaging-runtime/spec.md`). Redis Streams and Pub/Sub
  are forbidden for cross-context messaging.

## Key naming

All Redis keys MUST follow the pattern:

```
<context>:<purpose>:<identifier>
```

- `<context>`: the bounded context owning the key (matches `catalog.yaml`).
- `<purpose>`: short kebab-case label naming the use case
  (`session`, `scryfall-cache`, `rate-limit`).
- `<identifier>`: arbitrary stable identifier (UUID, hash, composite slug).

Examples:

```
identity:session:c1b3a4...
lexicon:scryfall-cache:card-id-abc123
gateway:rate-limit:ip-198.51.100.4
```

Keys not following this pattern MUST be considered illegal and SHOULD be
caught at code-review time. There is no runtime enforcement at v1.

## TTLs

Every key MUST be written with a TTL via `SET ... EX <seconds>` or
`EXPIRE <seconds>`. Cache entries without TTL are not allowed.

Recommended baselines:

- `session`: 24 hours
- `scryfall-cache`: 7 days
- `rate-limit`: rolling window in seconds (matches limit window)

## Provisioning

`rbrain-deploy` provisions one Redis instance running `>= 7.4`. There is no
ACL split per context at v1; every backend service authenticates with the
same `requirepass` secret. ACL-based isolation is deferred until a real risk
materializes.
