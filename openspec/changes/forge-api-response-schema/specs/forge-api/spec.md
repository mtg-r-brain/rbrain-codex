## ADDED Requirements

### Requirement: Machine-readable response-shape schema

The response shapes of the eight routes SHALL have a machine-readable projection in
`rbrain-codex`: `openspec/specs/forge-api/schema.yaml`, the peer of this document. The schema SHALL
carry a `components` block and a `routes` block; each route SHALL declare its method, path, and a
per-status `responses` map, and request-bearing routes SHALL declare their accepted request-body
fields. The schema's route set SHALL equal the closed eight enumerated in the "No other public HTTP
routes at v1" requirement — no more, no fewer — and its response shapes SHALL describe what this
document describes.

`rbrain-codex` CI SHALL run `bash scripts/validate-response-shapes.sh`, which SHALL fail when the
schema is not well-formed per its own documented grammar, when the schema's route set diverges from
the closed eight, or when this document stops declaring "exactly eight HTTP routes".

A change to a response shape, a route, an accepted request-body field, or a query parameter SHALL
update `schema.yaml` in the same OpenSpec cycle that carries the MODIFIED delta on this document —
the schema is this document's machine-readable projection, and the two SHALL stay in lockstep.

#### Scenario: The schema drifts from the closed route set

- **WHEN** `schema.yaml` gains a route `POST /decks/share` or drops `GET /decks`
- **THEN** `bash scripts/validate-response-shapes.sh` fails naming the missing or extra route, and codex CI goes red

#### Scenario: The schema loses a response field

- **WHEN** a response shape in `schema.yaml` omits a field that this document still describes (for example, `errors` on the stored-deck payload)
- **THEN** the schema SHALL be updated through the same MODIFIED delta on this document before it ships — a projection that lags the spec is a contract description a consumer has read in good faith
