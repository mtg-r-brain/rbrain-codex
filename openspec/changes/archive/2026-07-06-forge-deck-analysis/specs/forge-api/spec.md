## ADDED Requirements

### Requirement: Deck analysis endpoint

`rbrain-forge` SHALL expose `POST /decks/analyze` on its declared service port. The request body SHALL be a JSON object with exactly two fields:

- `decklist` (string, required) — the raw decklist text; missing or blank SHALL be rejected with `422`.
- `card_facts` (array, required — MAY be empty) — per-card facts supplied by the caller, each `{name, mana_cost, type_line}` (strings; `mana_cost`/`type_line` MAY be empty). Missing (absent key) SHALL be rejected with `422`. forge SHALL NOT fetch card data itself — it has no lexicon edge; supplying facts is the caller's job (cortex, per `service-topology`).

forge SHALL parse the decklist (same parser as `POST /decks/parse`) and respond `200` with exactly these fields:

| Field | Type | Description |
|---|---|---|
| `mana_curve` | object | Histogram of mainboard non-land cards by converted mana cost: keys `"0"`…`"6"` and `"7+"`, integer counts weighted by quantity. |
| `average_cmc` | number | Quantity-weighted mean CMC of mainboard non-land cards; `0` when none. |
| `color_distribution` | object | Counts of mana symbols `W`,`U`,`B`,`R`,`G`,`C` across mainboard costs, weighted by quantity (cost-symbol approximation of color identity). |
| `type_breakdown` | object | Mainboard counts by primary card type (Creature, Instant, Sorcery, Artifact, Enchantment, Planeswalker, Battle, Land, Other), weighted by quantity. |
| `total_mainboard` | integer | Sum of mainboard quantities (parsed, resolved or not). |
| `unresolved` | array | Mainboard card names with no matching entry in `card_facts` (case-insensitive name match); analysis SHALL proceed over the resolved remainder. |

Name matching against `card_facts` SHALL be case-insensitive on the exact name. CMC SHALL be derived from the `mana_cost` string (`{2}{R}` → 3; `{X}` counts 0; hybrid/phyrexian symbols count 1 each).

#### Scenario: Curve and colors from supplied facts

- **WHEN** `POST /decks/analyze` receives a mono-red list (`4 Lightning Bolt`, `56 Mountain`) with facts giving Lightning Bolt `{R}`/Instant and Mountain ``/`Basic Land — Mountain`
- **THEN** `mana_curve` SHALL be `{"1": 4}` (lands excluded), `average_cmc` `1`, `color_distribution.R` `4`, `type_breakdown` `{"Instant": 4, "Land": 56}`, `total_mainboard` `60`, and `unresolved` empty

#### Scenario: Unknown cards degrade gracefully

- **WHEN** a mainboard name has no matching fact
- **THEN** the name SHALL appear in `unresolved`, its quantity SHALL still count in `total_mainboard`, and every other metric SHALL be computed from the resolved cards; the response stays `200`

#### Scenario: Missing card_facts is unprocessable

- **WHEN** the body carries a `decklist` but no `card_facts` key
- **THEN** the response SHALL be `422`

## MODIFIED Requirements

### Requirement: No other public HTTP routes at v1

`rbrain-forge` SHALL expose exactly eight HTTP routes at v1: `GET /health` (defined by `repository-conventions`), the stateless in-cluster routes `POST /decks/parse` and `POST /decks/analyze`, and the user-scoped persistence routes `POST /decks`, `GET /decks`, `GET /decks/{id}`, `PUT /decks/{id}`, and `DELETE /decks/{id}` (defined here). Any additional route — deck sharing, legality, or batch endpoints — requires a MODIFIED delta on `forge-api` before the route ships.

The persistence routes (`/decks`, `/decks/{id}`) are reached only through the gateway's JWT-protected proxy (the `gateway → forge` edge); `POST /decks/parse` and `POST /decks/analyze` are stateless in-cluster routes serving the `cortex → forge` edge and are NOT gateway-proxied. forge serves all of them on its own port; authentication is the gateway's responsibility, ownership scoping (via `X-User-Id`) is forge's.

#### Scenario: New public route goes through OpenSpec

- **WHEN** a contributor adds a deck-sharing or legality endpoint to forge
- **THEN** the change SHALL include a MODIFIED requirement on this spec before the route ships; CI on forge alone is not enough to make it part of the surface

#### Scenario: Analyze is not publicly reachable

- **WHEN** an external client requests `POST /decks/analyze` through the gateway
- **THEN** the gateway SHALL NOT proxy it (the route is absent from `gateway-api`'s closed public set)
