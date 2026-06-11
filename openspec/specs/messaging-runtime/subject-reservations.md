# NATS subject prefix reservations

Reference document. The normative requirement lives in
`openspec/specs/messaging-runtime/spec.md` ("Subject naming follows the
platform convention").

The canonical regex every cross-context event subject MUST match:

```
^rbrain\.[a-z][a-z-]*\.[a-z][a-z0-9-]*$
```

This document describes how that namespace is partitioned.

## Reserved prefixes

Three prefix shapes exist, all under the global `rbrain.` namespace.

### `rbrain.<ctx>.<event>` — context-published events

Every bounded context publishing events MUST do so under the prefix
`rbrain.<own-context-name>.*`. The context name is the second segment and
matches `bounded-contexts/catalog.yaml`.

Examples:

- `rbrain.lexicon.card-released`
- `rbrain.forge.deck-saved`
- `rbrain.identity.user-registered`

A context SHALL NOT publish on another context's prefix. Validation tooling
(`validate-repo.sh`) enforces this by parsing `OWNERSHIP.yaml.publishes`.

### `rbrain.system.<event>` — platform control plane (reserved for `deploy`)

The prefix `rbrain.system.*` is reserved exclusively for `rbrain-deploy`,
which uses it to broadcast platform-level signals (rolling restart, drain
requests, health broadcasts). The convention exists so that backend services
can observe platform events without coupling to deployment specifics.

Only `rbrain-deploy` may declare `rbrain.system.*` in its
`OWNERSHIP.yaml.publishes`. `validate-repo.sh` enforces this carve-out.

Examples:

- `rbrain.system.rolling-restart`
- `rbrain.system.drain-requested`

### Out-of-band administrative prefixes

NATS server-level subjects (`$JS.>`, `$SYS.>`, `_INBOX.>`) are managed by
NATS itself and are NOT considered part of the `rbrain.` namespace. They are
not subject to this policy.

## Why these reservations

Two reasons:

1. **Routing safety.** A wildcard subscriber on `rbrain.lexicon.>` should only
   receive events from `lexicon`. If any other context could publish on that
   prefix, the subscriber would silently receive misrouted traffic.

2. **Audit trail.** Reading any subject string immediately tells the operator
   which context produced the event. No hidden producers.

## Anti-patterns (recap from spec.md)

- No version suffix in the subject (`rbrain.forge.deck-saved.v2`). Schema
  evolution happens in the payload, not the subject.
- No environment prefix (`rbrain.prod.forge.deck-saved`). Environment
  isolation is achieved via separate NATS accounts or clusters.
- No request-reply patterns over NATS for cross-context calls. HTTP via the
  synchronous call graph is the only route.
