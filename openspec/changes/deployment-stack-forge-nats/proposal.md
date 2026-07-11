## Why

`rbrain-forge`'s `forge-format-legality` (archived) made `NATS_URL` a required boot-time env var — `forge` consumes `rbrain.lexicon.card-legality-updated` from `lexicon`'s `LEXICON_CARDS` stream. The `deployment-stack` wiring requirement still describes `forge` as `DATABASE_URL`-only; the unified stack's `forge` container will now fail to boot (exit 78) the next time it's rebuilt from `main`.

## What Changes

- MODIFY `deployment-stack` "Complete internal environment wiring": `forge` gains `NATS_URL` (pointed at the shared `nats` service, same as `lexicon`/`oracle`/`identity`/`cortex`); `chronicle` keeps `DATABASE_URL`-only (unaffected, split out of the same clause `forge` used to share with it).

## Capabilities

### Modified Capabilities

- `deployment-stack`: `forge` wiring gains `NATS_URL`.

## Impact

- Contract text; the compose change ships alongside in `rbrain-deploy` (adds `NATS_URL: nats://nats:4222` and a `nats: condition: service_healthy` dependency to `forge`'s service entry).
