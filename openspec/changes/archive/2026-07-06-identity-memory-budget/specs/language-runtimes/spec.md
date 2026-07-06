## MODIFIED Requirements

### Requirement: Per-context memory budget

Each `rbrain-*` repo's `OWNERSHIP.yaml` SHALL declare an integer `max_rss_mb` field with the value listed below. CI SHALL fail a repo whose declared `max_rss_mb` differs from this table:

| Context | `max_rss_mb` |
|---|---|
| `gateway` | 35 |
| `identity` | 96 |
| `lexicon` | 30 |
| `oracle` | 40 |
| `forge` | 30 |
| `chronicle` | 25 |
| `cortex` | 200 |
| `app` | 100 |
| `deploy` | 0 |
| `codex` | 0 |

`identity`'s budget is dominated by a transient allocation, not steady state: the committed Argon2id parameters (`m=65536` per `identity-bootstrap-mvp`) allocate 64 MiB per in-flight password hash by design. Steady-state RSS is ~4 MB.

Raising or lowering any budget SHALL go through an OpenSpec change.

#### Scenario: Budget declaration is mandatory

- **WHEN** an `rbrain-*` repo's `OWNERSHIP.yaml` omits the `max_rss_mb` field
- **THEN** `scripts/validate-repo.sh` SHALL fail with an explicit message naming this requirement

#### Scenario: Runtime exceeding the budget

- **WHEN** a sibling repo's CI runs a load test on the service and observes RSS exceeding the declared `max_rss_mb`
- **THEN** the CI job SHALL fail; the resolution is either to optimize the service or to file an OpenSpec change amending this table

#### Scenario: Budget accounts for spec-mandated transients

- **WHEN** a capability spec mandates an algorithm with an explicit memory cost (e.g. Argon2id `m=65536`)
- **THEN** the owning context's budget SHALL cover that transient working set; a budget that makes a committed requirement unexecutable SHALL be treated as a defect in this table, not in the sibling

### Requirement: Platform-wide memory ceiling

The sum of all per-context `max_rss_mb` values plus the external dependency budgets (PostgreSQL: 256 MB, Redis: 50 MB, NATS: 40 MB) SHALL NOT exceed 1024 MB for a single-node deployment. The current sum is 902 MB, leaving 122 MB of headroom.

#### Scenario: Sum check on budget change

- **WHEN** an OpenSpec change raises one or more `max_rss_mb` values
- **THEN** validation tooling SHALL recompute the platform-wide total and SHALL reject the change if it crosses 1024 MB
