# NATS subject naming convention

This is a reference document. The normative requirement lives in
`openspec/specs/service-topology/spec.md` ("Asynchronous events use NATS JetStream").

## Format

All NATS JetStream subjects used for cross-context events MUST match the regex:

```
^rbrain\.[a-z][a-z-]*\.[a-z][a-z0-9-]*$
```

In words: three dot-separated segments.

| Segment | Value |
|---|---|
| 1 | Literal `rbrain` |
| 2 | The producer bounded context name (lowercase kebab-case, from `bounded-contexts/catalog.yaml`) |
| 3 | The event name in past-tense lowercase kebab-case |

## Reserved prefixes

- `rbrain.system.*` is **reserved exclusively for `deploy`** for platform-level
  signals (rolling restart announcements, drain commands, health broadcasts).
  No other context may publish on `rbrain.system.*`.

## Foreseeable event surface

The following table lists events that are likely to exist at v1 launch. It is
not exhaustive and not normative — each context's `OWNERSHIP.yaml.publishes`
is the authoritative source for the events that context emits.

| Producer | Subject | Carries |
|---|---|---|
| `lexicon` | `rbrain.lexicon.card-released` | New card or set ingested from Scryfall |
| `lexicon` | `rbrain.lexicon.catalogue-rebuilt` | Full catalogue rebuild finished |
| `identity` | `rbrain.identity.user-registered` | A new user account was created |
| `identity` | `rbrain.identity.user-deleted` | A user account was deleted (GDPR delete-me) |
| `forge` | `rbrain.forge.deck-saved` | A deck was created or updated |
| `forge` | `rbrain.forge.deck-deleted` | A deck was deleted |
| `chronicle` | `rbrain.chronicle.article-published` | A new article was published |
| `cortex` | `rbrain.cortex.conversation-ended` | A chat conversation was closed |
| `deploy` | `rbrain.system.rolling-restart` | A rolling restart of a service is starting |
| `deploy` | `rbrain.system.drain-requested` | A service has been asked to drain its connections |

## Anti-patterns

- **No request-reply over NATS for cross-context calls.** Synchronous request-response
  paths SHALL use HTTP per `service-topology`'s synchronous call graph.
- **No version suffixes in the subject** (e.g. `rbrain.forge.deck-saved.v2`). Schema
  evolution is handled by versioning the payload, not the subject.
- **No environment prefix** (e.g. `rbrain.prod.forge.deck-saved`). Environment isolation
  is achieved via separate NATS clusters or accounts, not via the subject.

## Past tense

Event names describe facts that happened. `deck-saved`, not `save-deck`. Verbs in
imperative form indicate commands, which belong to synchronous HTTP, not NATS.
