# Design — forge-api-response-schema

## Decision 1: a committed YAML schema in codex, not an OpenAPI route

The machine-readable projection lives at `openspec/specs/forge-api/schema.yaml` in `rbrain-codex`
and is validated by codex CI, exactly as `format-catalog/formats.yaml` and
`validate-formats.sh` handle the format whitelist. It is a peer of `spec.md` — the spec is the
canonical, normative document and the schema is its machine-checkable projection; the two SHALL
stay in lockstep.

Rejected alternatives:

- **Serving a generated OpenAPI document at forge runtime**: forge's request bodies are parsed as
  untyped `Json<Value>` (there is no serde model to derive a schema from), so a generated document
  would describe the *serialization layer*, not the contract — the deck payload is built field by
  field in handlers, not from a typed struct. The document would also be a second source of truth
  racing `spec.md`, and it would add a runtime route to a service whose closure requirement is
  "exactly eight HTTP routes" — a ninth public route would itself need a MODIFIED delta.
- **A JSON Schema served from codex at runtime**: couples the validator to a running server for
  data that is compile-time by nature; same dual-source objection.
- **Runtime schema validation in forge** (e.g. validating every outbound payload against the
  schema before replying): the strongest guarantee, but it moves the schema into a production
  dependency of forge — a Rust service with no YAML dependency today — and it still does not
  replace the drift check on the *route set*. CI-time comparison is the minimal, dependency-free
  gate; runtime validation can be layered later if wanted.

## Decision 2: a grammar the schema checks itself against

`schema.yaml` documents its own field grammar in its header (`type` plus optional `nullable`,
`required`, `enum`, `items`, `fields`, `additional`; valid kinds `string`, `integer`, `number`,
`boolean`, `object`, `array`, `null`). The validator's self mode walks the file and asserts every
declared type and every field-spec key is from the closed set, and that every component reference
resolves. This keeps the file from silently inventing a grammar the validator cannot check.

## Decision 3: three modes — self, sibling, runtime

- **Self mode** (`bash scripts/validate-response-shapes.sh` in codex): asserts the schema is
  well-formed per the grammar, the schema's route set is exactly the closed eight, and the spec
  still declares "exactly eight HTTP routes". This is the codex CI step; it is the `format-catalog`
  analogue of checking the catalog against its own closure.
- **Sibling mode** (`bash scripts/validate-response-shapes.sh <repo-path>`): reads the target
  repo's `OWNERSHIP.yaml` `context` — the same identity mechanism `validate-repo.sh` trusts — and
  for `forge` compares the Axum route set in `src/lib.rs` to the schema. Any other context dies
  loudly rather than no-oping, so mis-wiring a CI step is visible. Wire it into forge's CI in the
  sibling chore commit, mirroring `validate-formats.sh`.
- **Runtime mode** (opt-in `FORGE_URL`): calls forge's stateless routes (`GET /health`,
  `POST /decks/parse`, `POST /decks/analyze`) and type-checks the bodies against the schema's
  response shapes. The persistence routes are out of scope: they need `X-User-Id` and a database,
  so they are not a stateless smoke. This is a developer/QA tool, never a CI dependency.

## Decision 4: script mechanics

- Bash 3.2-compatible (no `mapfile`, no `declare -A`), because unlike the Ubuntu-only validators
  this script is part of the documented local gate sequence on contributor macOS. Relies on `yq`
  only, matching the other validators.
- yq v4 returns YAML tags from `type` (`!!map`, `!!seq`, `!!str`, `!!int`, `!!float`, `!!null`),
  not jq's lowercase names; the schema's `number` is therefore checked as `!!int or !!float`. The
  script's header documents this so a future maintainer does not "fix" it into a bug.
- Sibling extraction flattens `src/lib.rs` onto one line before cutting per `.route(` call, because
  Axum allows a `.route(` to span lines (forge writes `/{id}` on the line after the call). Paths
  are normalized `:param` → `{param}` to the spec's notation, and methods are uppercased to match
  the schema's `GET`/`POST`/`PUT`/`DELETE`.

## Ordering note

Self mode greps the CANONICAL `forge-api/spec.md`, which gains the new machine-readability
requirement only at sync. The validator therefore passes locally only after `openspec archive` has
promoted the deltas — run the full suite at the sync step, not at the feat step, and only wire the
forge sibling step after the forge chore commit, the same ordering as `validate-formats.sh`.
