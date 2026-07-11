## Context

Trivial, single-variable wiring fix — recorded because the `spec-driven` schema requires the artifact. No design decisions of substance: `forge` joins the same shared `nats` service every other NATS-consuming container in this compose already uses.

## Goals / Non-Goals

**Goals:** unblock `forge`'s boot in the unified stack. **Non-Goals:** no change to any other service's wiring.

## Decisions

- `NATS_URL: nats://nats:4222` — identical value to `lexicon`/`oracle`/`identity`/`cortex`'s existing entries, not a new port or topology.

## Risks / Trade-offs

- **[Risk]** None — `forge` only ever reads (`get_stream`, never `create_stream`); joining the shared broker cannot collide with `lexicon`'s ownership of `LEXICON_CARDS`.
