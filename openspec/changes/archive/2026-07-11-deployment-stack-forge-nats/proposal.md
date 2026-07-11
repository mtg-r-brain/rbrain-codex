## Why

`rbrain-forge`'s `forge-format-legality` (archived) made `NATS_URL` a required boot-time env var — `forge` consumes `rbrain.lexicon.card-legality-updated` from `lexicon`'s `LEXICON_CARDS` stream. The `deployment-stack` wiring requirement still describes `forge` as `DATABASE_URL`-only; the unified stack's `forge` container will now fail to boot (exit 78) the next time it's rebuilt from `main`.

Separately, `service-topology`'s canonical local-dev port map still reserves NATS port `4225` for forge as a future **producer** (`rbrain.forge.*` events) — a reservation made before ADR 0002 existed. ADR 0002 settled forge's actual role as a **consumer** of lexicon's stream, never a publisher; the reservation is stale and the table doesn't reflect what forge's `.env.example` (shipped in `forge-format-legality`) actually documents (`NATS_URL=nats://localhost:4222`, lexicon's port).

## What Changes

- MODIFY `deployment-stack` "Complete internal environment wiring": `forge` gains `NATS_URL` (pointed at the shared `nats` service, same as `lexicon`/`oracle`/`identity`/`cortex`); `chronicle` keeps `DATABASE_URL`-only (unaffected, split out of the same clause `forge` used to share with it).
- MODIFY `service-topology` "Canonical local-development port map": forge's row changes from `4225` (reserved producer port) to `— (uses lexicon's NATS, 4222)`, mirroring cortex's existing row exactly. The stale "forge's NATS port reserved for producer role" footnote is removed — if forge ever needs to publish its own events, that need claims a port at that time, per this same requirement's own stated rule.

## Capabilities

### Modified Capabilities

- `deployment-stack`: `forge` wiring gains `NATS_URL`.
- `service-topology`: forge's canonical local-dev NATS port entry corrected from a stale producer reservation to its actual consumer role.

## Impact

- Contract text; the compose change ships alongside in `rbrain-deploy` (adds `NATS_URL: nats://nats:4222` and a `nats: condition: service_healthy` dependency to `forge`'s service entry). `forge`'s own `.env.example` (already shipped) is unaffected — it already documents the consumer role correctly.
