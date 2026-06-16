## Context

`repository-conventions` mandates that every service reads `PORT` and defaults to `8080`. `service-topology` defines the synchronous call graph (`sync-graph.yaml`) and the gateway-as-sole-ingress rule, but says nothing about which host port each service uses in local development. With 6+ backend services on one dev host, `8080` collides immediately, so each service overrides `PORT` — but the override values were never written down in one place, and the per-repo `.env.example` files drifted apart (gateway's is wrong on every downstream URL).

## Goals / Non-Goals

**Goals:**

- One canonical table of local-dev ports (HTTP, NATS, Postgres) per context.
- Correct the broken `.env.example` files so a fresh clone runs.
- Reserve ports for chronicle and forge so they slot in without renegotiation.

**Non-Goals:**

- Changing the production `8080` bind default (each prod pod keeps `8080`; the map is a local-host collision-avoidance device).
- Renumbering any running service.
- A machine-readable `ports.yaml` with a CI validator — there is no port-validation tooling today, so a separate artifact would duplicate the spec table and rot. The markdown table in the spec is the source of truth; a `ports.yaml` can follow if/when a validator exists (mirroring `sync-graph.yaml`).
- Creating `.env.example` for chronicle/forge — they are not functional services yet; their ports are reserved in the table and their config files arrive with their first real slice.

## Decisions

### Decision 1: Codify the de-facto map, do not renumber

**Choice:** The canonical table is exactly what already runs: lexicon 8080, cortex 8081, oracle 8082, identity 8083, gateway 8090; NATS 4222/4223/4224; PG 5432/5433/5434/5435.

**Rationale:** The running stack, the cold-resume recipes, and muscle memory all already use these. A "cleaner" contiguous renumber buys nothing and would invalidate every recipe and running process. Codifying reality is the lowest-risk way to kill the drift.

### Decision 2: Gateway at 8090, offset from the 808x block

**Choice:** Gateway keeps `8090`, not `8084`.

**Rationale:** The `808x` block reads as "internal backend services"; the gateway is the one public ingress (`service-topology` → "Gateway is the sole public ingress"). The numeric offset is a small but useful signal of that architectural boundary. It is also already the running value.

### Decision 3: chronicle 8084 / forge 8085, forge NATS 4225, PG 5436/5437

**Choice:** Reserve the next contiguous HTTP numbers and PG ports for the two not-yet-online services; give forge a NATS port (it publishes `rbrain.forge.deck-saved` per the call graph) and leave chronicle without one (no events in the topology today).

**Rationale:** Reserving now prevents a future collision scramble. forge's NATS reservation matches its declared producer role; chronicle gets one assigned later if it ever publishes.

### Decision 4: Fix cortex's missing required `NATS_URL` in the same slice

**Choice:** Add `NATS_URL=nats://localhost:4224` to `rbrain-cortex/.env.example`.

**Rationale:** Since the identity-event listener landed, cortex exits `78` at boot without `NATS_URL`, yet its `.env.example` never listed it — a fresh clone fails to boot. It is the same class of defect as Finding B (a `.env.example` that doesn't match what the service needs) and belongs in this consistency pass rather than a separate trivial change.

## Risks / Trade-offs

- **Spec table can still drift from reality** without a validator. Accepted for now (see Non-Goals); the single canonical location at least makes drift detectable by eye, and a future `ports.yaml`+check can enforce it. Noted as a follow-on.
- **Cross-repo edits span multiple repos** but touch only `.env.example` (no code), so the blast radius is config-only.

## Migration

None. Re-copying `.env.example` yields correct values; running services are unaffected.
