## Why

`rbrain-forge` owns deck parsing, storage, and analysis (per `bounded-contexts`), and the `service-topology` graph already declares the `cortex → forge` edge for "deck operations used as agent tools (parse, analyze, validate)". But forge is scaffold-only: it has no public contract and no behavior. This change defines `forge-api`'s first route — synchronous **deck-list parsing** — so cortex can later expose a `parse_deck` tool. It is a parse-only tracer slice: no persistence (forge's Postgres schema arrives with a later storage slice).

## What Changes

- ADD a `forge-api` capability with:
  - "Deck-list parse endpoint" — `POST /decks/parse` taking a raw decklist string and returning the structured deck (mainboard / sideboard / commander / maybeboard entries + non-fatal parse errors).
  - "No other public HTTP routes at v1" — `GET /health` + `POST /decks/parse` only (per `repository-conventions`' route-enumeration rule for `<context>-api` capabilities).

The detailed parsing semantics (accepted line shapes, section headers, annotation stripping, error reporting) are specified by `rbrain-forge`'s own `forge-deck-parsing` capability in the sibling implementation change; this contract fixes the wire shape.

## Capabilities

### New Capabilities

- `forge-api`: the public HTTP contract for forge — deck-list parsing route + the closed public-route set.

## Impact

- **Contract only** here. Implementation lands in the sibling `rbrain-forge` change `forge-deck-parsing` (PORT handling, parser, handler, tests).
- **No new sync edge** (`cortex → forge` already exists; the parse route is its first concrete use).
- **No NATS / no persistence** in this slice.
- **Specs touched**: codex `forge-api` (new).
