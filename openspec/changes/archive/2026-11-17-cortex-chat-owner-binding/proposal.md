# Proposal — cortex-chat-owner-binding

## Why

The 2026-11-17 full-stack bring-up (first run of the whole platform with a live
LLM) surfaced a data-integrity gap that no unit test or CI gate could see: every
conversation created through `POST /chat` lands in `cortex.conversations` with
`user_id` **NULL**.

The identity is on the wire. `gateway-api` has required since v1 that the gateway
inject `X-User-Id: <sub>` into every forwarded `/chat` request (and strip any
client-supplied one), and cortex already parses that header for the deck-analysis
composition route and forwards it to its tools — the `build_deck`/`finalize_deck`
tools scope by owner with it. The conversation store has always accepted an owner
(`new_conversation(user_id=...)`, persisted into the `user_id` uuid column), and
the identity listener already attributes its prewarmed conversations. Only the
chat handler drops the value on the floor: it calls `store.new_conversation()`
with no owner, so chat conversations are anonymous from birth.

The cost is concrete: no per-account chat history is queryable, a right-to-erasure
purge cannot find a user's conversations, and `cortex-conversation-prewarming`
task 6.2 (a `cortex.conversations` row with `user_id` + seed messages) can never
be closed honestly for the chat path.

`cortex-api` never mentioned identity on `POST /chat` at all — the request-body
requirement closes over exactly `message` and `conversation_id`, and the
`X-User-Id` contract existed only on the deck-analysis route. The gap is in the
rule, not in the implementation's plumbing: every other part of the lane already
honors the owner.

## What Changes

- `cortex-api` gains one ADDED requirement: **POST /chat conversation owner
  attribution**. A newly allocated conversation SHALL be attributed to the trusted
  `X-User-Id` header when present; a request carrying a non-UUID `X-User-Id` SHALL
  be rejected `400` (never a `500`); a request without the header keeps allocating
  an unattributed conversation, preserving the anonymous in-cluster call path.
  Continuing an existing conversation never rewrites its owner.
- `rbrain-cortex` ships the one-line router fix plus the header-shape guard, and
  tests for the four cases.

## Non-goals

- Owner enforcement on continuation (user B continuing user A's conversation id).
  Conversation ids are server-allocated UUID4s and no read route exists; adding a
  403 lane on continuation is a separate change with its own threat-model note.
- Any new route, request-body field, or response field. The request body stays
  exactly the two fields it is today; identity stays a trusted-header concern.

## Impact

- Affected specs: `cortex-api` (ADDED requirement).
- Affected code: `rbrain-cortex/app/chat/router.py` (+ tests). No gateway change —
  the gateway already conforms to `gateway-api` on this edge.
- Cross-context consumers: none gain or lose fields; the column that stops being
  NULL is already declared in `data-stores`/cortex migrations.
