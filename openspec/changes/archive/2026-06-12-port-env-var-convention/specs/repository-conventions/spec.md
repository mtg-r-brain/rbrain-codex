## ADDED Requirements

### Requirement: Port binding honors a PORT environment variable

Every `rbrain-*` sibling whose `OWNERSHIP.runtime` is NOT `none` SHALL read a `PORT` environment variable at startup and bind its HTTP server to that port. When `PORT` is absent or cannot be parsed as a `u16`, the sibling SHALL silently fall back to port `8080`.

The fallback SHALL be silent in the sense of "non-fatal" — a log line MAY be emitted, but the boot SHALL NOT exit on a missing or malformed `PORT`. This matches the convention used by PaaS-style runners (Heroku, Cloud Run, Railway) where `PORT` is injected by the platform and a typo shouldn't crash the pod.

`rbrain-codex` and `rbrain-deploy` (both declared `runtime: none`) are explicitly out of scope and SHALL NOT need to implement this requirement.

Python siblings using `uvicorn` as their CLI entrypoint MAY satisfy this requirement via the `--port` flag with `${PORT:-8080}` substitution rather than reading `PORT` programmatically in `main.py`.

#### Scenario: Default port is 8080

- **WHEN** a sibling starts without `PORT` set in the environment
- **THEN** the HTTP server SHALL bind to port `8080`

#### Scenario: PORT override is honored

- **WHEN** a sibling starts with `PORT=8082` in the environment
- **THEN** the HTTP server SHALL bind to port `8082`; `curl http://host:8082/health` SHALL return the canonical health payload

#### Scenario: Unparseable PORT falls back silently to 8080

- **WHEN** a sibling starts with `PORT=not-a-number` in the environment
- **THEN** the HTTP server SHALL bind to port `8080`; the process SHALL NOT exit non-zero on the parse failure

#### Scenario: codex and deploy are out of scope

- **WHEN** a contributor checks `rbrain-codex` or `rbrain-deploy` for `PORT` handling
- **THEN** they SHALL find none; both repos declare `runtime: none` in their OWNERSHIP.yaml and serve no HTTP surface
