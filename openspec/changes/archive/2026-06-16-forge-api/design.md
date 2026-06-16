## Context

forge is the only context owning `deck`/`deck-list`/`sideboard`/`mainboard`/`maybeboard` vocabulary. cortex will call it as an agent tool. The first useful, dependency-free capability is turning a pasted decklist into structured data — no database, no card validation (that would call lexicon, an edge forge does not have).

## Goals / Non-Goals

**Goals:** a stable wire contract for `POST /decks/parse`; the closed public-route set.

**Non-Goals:** persistence (later slice + forge Postgres `:5437`); card existence/legality validation (needs lexicon — not a forge edge); analysis/statistics; NATS events.

## Decisions

### Decision 1: Parse is pure and forgiving

The endpoint is a pure function (input string → structured output), so it needs no state, no DB, no auth context beyond the gateway's. Parsing is **forgiving**: unrecognised lines do not fail the request; they are collected into an `errors` array so a user pasting a slightly-off list still gets the lines that parsed. A `200` with some `errors` is the normal shape; only a malformed *request* (missing `decklist`) is a `4xx`.

### Decision 2: Sections in the response

The response separates `mainboard`, `sideboard`, `commander`, and `maybeboard` (forge's owned vocabulary) rather than a flat list, because downstream deck analysis and legality treat them differently. Each is a list of `{quantity, name}`. `total_mainboard` is included as a convenience count.

### Decision 3: Wire shape fixed here; semantics in forge

This contract pins the request/response JSON shape (so cortex's tool can depend on it). The *how* of parsing — which header words name which section, how Arena `(SET) NUM` annotations are stripped, what counts as an error — is forge's implementation detail, specified in forge's `forge-deck-parsing` capability and free to improve without a contract change.

## Migration

None — new capability.
