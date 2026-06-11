## ADDED Requirements

### Requirement: Frozen per-context runtime allocation

Each bounded context SHALL be implemented in exactly one of the runtimes listed below, and no other:

| Context | Runtime |
|---|---|
| `gateway` | Rust |
| `identity` | Rust |
| `lexicon` | Rust |
| `oracle` | Rust |
| `forge` | Rust |
| `chronicle` | Rust |
| `cortex` | Python |
| `app` | TypeScript (Node.js) |
| `deploy` | none |
| `codex` | none |

A context's `OWNERSHIP.yaml.runtime` field SHALL match this allocation. Migrating a context to a different runtime SHALL require an OpenSpec change amending this requirement.

#### Scenario: Allocation is enforced at validation time

- **WHEN** `scripts/validate-repo.sh` runs against any `rbrain-*` repo
- **THEN** it SHALL fail if `OWNERSHIP.yaml.runtime` does not match the value listed for that context in this requirement

#### Scenario: Migration request without spec change is rejected

- **WHEN** a contributor proposes switching `chronicle` from Rust to TypeScript without an accompanying OpenSpec change
- **THEN** the proposal SHALL be rejected; the only path to changing the allocation is amending this requirement

### Requirement: Minimum runtime and framework versions

Every runtime and core framework used by an `rbrain-*` repo SHALL meet or exceed the version floors below. CI SHALL fail any build that uses a lower version:

- Rust toolchain: `>= 1.83.0`
- Python interpreter: `>= 3.12.0`
- Node.js runtime: `>= 22.0.0` (LTS line)
- Next.js: `>= 15.0.0`
- Axum: `>= 0.7.0`
- Tokio: `>= 1.40.0`
- SQLx: `>= 0.8.0`
- FastAPI: `>= 0.115.0`
- LangGraph: `>= 0.2.0`

Bumping any floor SHALL go through an OpenSpec change that updates this requirement and the design table.

#### Scenario: CI catches a stale Rust toolchain

- **WHEN** a Rust `rbrain-*` repo's `rust-toolchain.toml` pins `1.80.0`
- **THEN** CI SHALL fail with a clear error pointing at the version floor for Rust in this requirement

#### Scenario: Bump procedure

- **WHEN** a contributor wants to raise the Rust floor from `1.83.0` to `1.85.0`
- **THEN** they SHALL open an OpenSpec change that updates this requirement; the change SHALL document the gain that justifies the bump

### Requirement: Per-context memory budget

Each `rbrain-*` repo's `OWNERSHIP.yaml` SHALL declare an integer `max_rss_mb` field with the value listed below. CI SHALL fail a repo whose declared `max_rss_mb` differs from this table:

| Context | `max_rss_mb` |
|---|---|
| `gateway` | 35 |
| `identity` | 25 |
| `lexicon` | 30 |
| `oracle` | 40 |
| `forge` | 30 |
| `chronicle` | 25 |
| `cortex` | 200 |
| `app` | 100 |
| `deploy` | 0 |
| `codex` | 0 |

Raising or lowering any budget SHALL go through an OpenSpec change.

#### Scenario: Budget declaration is mandatory

- **WHEN** an `rbrain-*` repo's `OWNERSHIP.yaml` omits the `max_rss_mb` field
- **THEN** `scripts/validate-repo.sh` SHALL fail with an explicit message naming this requirement

#### Scenario: Runtime exceeding the budget

- **WHEN** a sibling repo's CI runs a load test on the service and observes RSS exceeding the declared `max_rss_mb`
- **THEN** the CI job SHALL fail; the resolution is either to optimize the service or to file an OpenSpec change amending this table

### Requirement: Platform-wide memory ceiling

The sum of all per-context `max_rss_mb` values plus the external dependency budgets (PostgreSQL: 256 MB, Redis: 50 MB, NATS: 40 MB) SHALL NOT exceed 1024 MB for a single-node deployment. The current sum is 831 MB, leaving 193 MB of headroom.

#### Scenario: Sum check on budget change

- **WHEN** an OpenSpec change raises one or more `max_rss_mb` values
- **THEN** validation tooling SHALL recompute the platform-wide total and SHALL reject the change if it crosses 1024 MB
