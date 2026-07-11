## 1. Contract

- [ ] 1.1 `deployment-stack`: MODIFY forge wiring (`NATS_URL`, split out of the shared `forge`/`chronicle` clause)
- [ ] 1.2 `service-topology`: MODIFY forge's canonical local-dev NATS entry from the stale `4225` producer reservation to `— (uses lexicon's NATS, 4222)`, matching forge's already-shipped `.env.example`
- [ ] 1.3 `openspec validate deployment-stack-forge-nats --strict` passes

## 2. Compose change (ships alongside, in rbrain-deploy)

- [x] 2.1 `rbrain-deploy/docker-compose.yaml`: `forge` service gains `NATS_URL: nats://nats:4222` and `depends_on: nats: condition: service_healthy`

## 3. Archive

- [ ] 3.1 Push planning commit; archive; push archive commit
