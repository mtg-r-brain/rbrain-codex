## MODIFIED Requirements

### Requirement: Complete internal environment wiring

The compose file SHALL set every environment variable each service requires, with service-to-service URLs addressing compose service names over the internal network (never `localhost`): gateway receives `JWT_SECRET`, `CORS_ALLOWED_ORIGINS` (defaulting to the app's browser-facing origin, `http://localhost:3000`, operator-overridable), plus `IDENTITY_URL`, `CORTEX_URL`, `LEXICON_URL`, `ORACLE_URL`, `FORGE_URL`, `CHRONICLE_URL`; identity receives `DATABASE_URL`, `JWT_SECRET`, `NATS_URL`; lexicon and oracle receive `DATABASE_URL`, `NATS_URL`; forge and chronicle receive `DATABASE_URL`; cortex receives `DATABASE_URL`, `NATS_URL`, `LEXICON_URL`, `ORACLE_URL`, `FORGE_URL`, and the `LLM_PROVIDER` configuration; app receives `GATEWAY_URL` (the in-network gateway base URL its BFF proxy calls, per ADR 0001) and `PUBLIC_GATEWAY_URL` (the browser-facing gateway URL, used only for the OAuth top-level navigation redirect). `JWT_SECRET` SHALL be the same value for identity and gateway, sourced from the operator environment.

#### Scenario: Identity and gateway share the signing secret

- **WHEN** a user registers through the stack and then calls a protected route with the returned JWT
- **THEN** the gateway SHALL verify the token successfully, proving both containers received the same `JWT_SECRET`

#### Scenario: No localhost across containers

- **WHEN** the compose file is inspected for `*_URL` and `NATS_URL` values
- **THEN** every cross-service value SHALL reference a compose service name; `localhost`/`127.0.0.1` SHALL appear only in host-facing examples, never in container-to-container wiring

#### Scenario: The browser origin is CORS-admitted

- **WHEN** the app served on its host port issues a cross-origin request to the gateway (e.g. `GET /articles` with `Origin: http://localhost:3000`)
- **THEN** the gateway SHALL answer with the matching `Access-Control-Allow-Origin` header, and preflights on the CORS-covered routes SHALL succeed

#### Scenario: The app proxies with in-network wiring

- **WHEN** a logged-in browser calls the app's `/api/decks`
- **THEN** the app server SHALL reach the gateway through `GATEWAY_URL` (compose service name), and no gateway URL SHALL be baked into the app's client bundle at build time
