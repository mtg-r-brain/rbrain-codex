## MODIFIED Requirements

### Requirement: rbrain-gateway gates protected routes behind a Bearer JWT

`rbrain-gateway` SHALL expose `POST /chat`, `GET /cards/{scryfall_id}`, `GET /cards`, `GET /rules/{number}`, `POST /decks`, `GET /decks`, and `GET /decks/{id}` as **JWT-protected** reverse proxies — to cortex, lexicon, oracle, and forge respectively. Every protected request SHALL carry a valid `Authorization: Bearer <jwt>` header.

Missing Authorization header, malformed Bearer scheme, signature mismatch, expired token, or HS256-incompatible algorithm SHALL all produce `401 Unauthorized` with body `{"error": "invalid token"}`. The wire response SHALL NOT distinguish among these failure modes — identical body on every 401 path.

JWT verification SHALL use HS256 with the shared `JWT_SECRET` env var (same secret identity uses for signing). On success the gateway SHALL inject `X-User-Id: <sub>` into the forwarded request (and strip any client-supplied `X-User-Id`), as for the other protected routes.

#### Scenario: Valid Bearer JWT proxies the chat to cortex

- **WHEN** a client posts `POST /chat` with `Authorization: Bearer <valid-jwt>` and a body cortex accepts
- **THEN** gateway SHALL verify the JWT, extract the `sub` claim, forward the request to `${CORTEX_URL}/chat` with `X-User-Id: <sub>` injected, and re-emit cortex's response

#### Scenario: Deck save is proxied to forge with the user id

- **WHEN** a client posts `POST /decks` with a valid Bearer JWT
- **THEN** gateway SHALL forward to `${FORGE_URL}/decks` with `X-User-Id: <sub>` injected (and any inbound `X-User-Id` stripped), and re-emit forge's response

#### Scenario: Missing Authorization header returns 401

- **WHEN** a client posts `POST /chat` without an Authorization header
- **THEN** gateway SHALL return `401 Unauthorized` with `{"error": "invalid token"}`; gateway SHALL NOT forward the request to cortex

#### Scenario: Expired JWT returns 401

- **WHEN** a client posts `GET /cards/<id>` with a JWT whose `exp` is in the past
- **THEN** gateway SHALL return `401 Unauthorized` with `{"error": "invalid token"}`
