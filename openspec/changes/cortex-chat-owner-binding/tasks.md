# Tasks — cortex-chat-owner-binding

Spec delta in this repo + the one-line cortex fix it contracts. The gateway needs
nothing: it already injects `X-User-Id` on `/chat` per `gateway-api`.

## 1. Ship the delta

- [x] Write the `cortex-api` delta: ADDED "POST /chat conversation owner attribution" (attribute-at-allocation, malformed header → 400, anonymous path preserved, continuation never rewrites the owner)
- [x] `openspec validate cortex-chat-owner-binding --strict`

## 2. Cortex implementation slice (`rbrain-cortex`)

- [ ] `app/chat/router.py`: pass the parsed `X-User-Id` into `store.new_conversation(...)` so allocation attributes the row
- [ ] `app/chat/router.py`: reject a present-but-malformed `X-User-Id` with `400` + JSON `error` before any allocation
- [ ] Tests in `tests/test_chat_endpoint.py`: attributed creation, anonymous creation stays NULL, malformed header → 400 with no allocation, continuation leaves the owner untouched
- [ ] `pytest` + repo lint/type gates green

## 3. Live verification (the smoke that found the defect)

- [ ] Rebuild the `rbrain-cortex` image, restart the stack slice, `POST /chat` with a Bearer JWT through the gateway, and assert the new `cortex.conversations` row carries the token's `sub` in `user_id`
- [ ] Confirm an anonymous direct-to-cortex `POST /chat` still allocates a NULL-owner row

## 4. Land

- [ ] `🔄 sync(cortex-chat-owner-binding)` — promote the ADDED requirement to the canonical `cortex-api` spec
- [ ] `📦 archive(cortex-chat-owner-binding)`
