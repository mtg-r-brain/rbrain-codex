## Why

Every `rbrain-*` service binds `8080` by default (`repository-conventions` → "Port binding honors a PORT environment variable"). That default is correct in production, where each service runs in its own pod. But in local development all services share one host, so each must override `PORT` to a distinct value — and there is no canonical record of which service owns which number.

The result is drift. Each repo's `.env.example` invented its own local mapping, and they disagree. The `rbrain-gateway` example is actively wrong:

```
IDENTITY_URL=http://localhost:8080   # actually lexicon's port
CORTEX_URL=http://localhost:8000     # cortex runs on 8081
LEXICON_URL=http://localhost:8001    # lexicon runs on 8080
ORACLE_URL=http://localhost:8002     # oracle runs on 8082
PORT=8088                            # gateway runs on 8090
```

A developer copying that example gets a gateway that cannot reach any backend. This is Finding B in the platform log.

## What Changes

- ADD a `service-topology` requirement codifying the canonical **local-development** port map — HTTP, NATS, and Postgres host ports per context — as the single source of truth. This is a local-dev collision-avoidance convention; it does NOT change the production `8080` bind default.
- The map codifies exactly the de-facto ports already running (zero churn to the live stack):

  | context | HTTP | NATS | Postgres |
  |---|---|---|---|
  | lexicon | 8080 | 4222 | 5432 |
  | cortex | 8081 | (uses identity 4224) | 5433 |
  | oracle | 8082 | 4223 | 5434 |
  | identity | 8083 | 4224 | 5435 |
  | chronicle | 8084 | — | 5436 |
  | forge | 8085 | 4225 | 5437 |
  | gateway | 8090 | — | — |
  | app (frontend) | 3000 | — | — |

  Gateway sits at `8090` (offset from the `808x` block) to signal it is the public ingress. chronicle and forge ports are reserved here for when those services come online.
- Fix `rbrain-gateway/.env.example` to the correct downstream ports and `PORT=8090`.
- Fix `rbrain-cortex/.env.example`: add the **required** `NATS_URL=nats://localhost:4224` (cortex exits `78` at boot without it since the identity-event listener landed) and note its HTTP port (`uvicorn --port 8081`).
- Add a brief "HTTP port: 808x" note to each backend repo's `.env.example` so the local port is discoverable next to its DSN/NATS config.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `service-topology`: ADDED requirement "Canonical local-development port map".

## Impact

- **Code**: no service code changes. Edits to `.env.example` in rbrain-gateway, rbrain-cortex, rbrain-lexicon, rbrain-oracle, rbrain-identity (rbrain-app already correct). chronicle/forge get no `.env.example` yet (not functional; their ports are reserved in the spec table).
- **Specs touched**: codex `service-topology` (this change). Cross-repo `.env.example` edits land in their own repos referencing this change.
- **Behavior**: documentation/config only; corrects a broken example. No wire or runtime change to running services.
- **Migration**: none. Developers re-copying `.env.example` get correct values.
- **Closes**: Finding B.
