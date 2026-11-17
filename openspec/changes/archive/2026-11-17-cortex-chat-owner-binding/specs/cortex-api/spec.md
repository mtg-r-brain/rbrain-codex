# cortex-api — Delta

## ADDED Requirements

### Requirement: POST /chat conversation owner attribution

`rbrain-cortex` SHALL attribute every newly allocated `POST /chat` conversation to
the trusted `X-User-Id` header — the `cortex.conversations` row SHALL carry that id
in its `user_id` column. A conversation is newly allocated when the request carries
no `conversation_id`, or one the server does not recognise. The header is trusted
exactly as on the deck-analysis route — injected by the gateway from the verified
JWT `sub` (per `gateway-api`), with any client-supplied value stripped; cortex does
NOT verify JWTs.

A request whose `X-User-Id` header is present but is not a parseable UUID SHALL be
rejected with `400` and a JSON `error` body — never a `500`.

A request **without** the header SHALL keep allocating an unattributed
conversation (`user_id` NULL), preserving the anonymous in-cluster call path.

Continuing an existing conversation SHALL never rewrite its owner — attribution
happens exactly once, at allocation.

This requirement changes no request or response body shape: identity travels only
in the header, and the `POST /chat` request body keeps its exact two fields.

#### Scenario: Authenticated creation attributes the conversation

- **WHEN** `POST /chat` arrives with `X-User-Id: U` (a valid UUID) and no
  `conversation_id`
- **THEN** the response SHALL carry a freshly allocated `conversation_id` whose
  `cortex.conversations` row has `user_id = U`

#### Scenario: Anonymous creation stays unattributed

- **WHEN** `POST /chat` arrives with no `X-User-Id` header (direct in-cluster
  caller) and no `conversation_id`
- **THEN** the conversation SHALL be allocated with `user_id` NULL and the turn
  SHALL otherwise behave identically

#### Scenario: Malformed identity header is a 400

- **WHEN** `POST /chat` arrives with `X-User-Id: not-a-uuid`
- **THEN** the response SHALL be `400` with a JSON `error` body, and no
  conversation SHALL be allocated

#### Scenario: Continuation never rewrites the owner

- **WHEN** `POST /chat` continues an existing conversation attributed to `U` while
  carrying `X-User-Id: V` (`U != V`)
- **THEN** the turn SHALL be appended and the row's `user_id` SHALL remain `U`
