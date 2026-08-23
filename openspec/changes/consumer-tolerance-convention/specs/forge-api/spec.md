# forge-api — Delta

## MODIFIED Requirements

### Requirement: Additive response fields and consumer tolerance

An additive change to a forge response payload SHALL be documented in this contract before it ships, **and** a consumer of a forge response SHALL ignore fields it does not recognise rather than rejecting the payload. Both obligations hold at once: neither one alone is sufficient, and each covers the other's failure mode.

The producer obligation is the delta gate stated by the closure requirement above. The consumer obligation constrains how `rbrain-cortex`, `rbrain-app`, and any future reader of a forge payload build their models of it: a deserialiser configured to reject unknown fields turns a backwards-compatible widening on forge's side into a runtime failure on the consumer's side, on a route that was working. Consumers SHALL NOT be configured that way against a forge payload.

A consumer that wants eager detection of contract drift SHALL obtain it from a contract test comparing a recorded forge payload against its expected field set, where a mismatch fails that consumer's CI — not from strict rejection in the model that serves production traffic.

This requirement is the forge-specific statement of the platform-wide rule defined by `repository-conventions` ("Consumer tolerance of additive response fields"), which is the authoritative source. The rule applies to every `<context>-api` contract, forge's included.

#### Scenario: forge grows a response field

- **WHEN** forge adds a field to the full stored deck payload, documented by a MODIFIED delta on this spec
- **THEN** a consumer deserialising that payload SHALL continue to operate on the fields it knows, ignoring the new one, without a lockstep release

#### Scenario: A consumer rejects an unknown field

- **WHEN** a consumer's forge-payload model is configured to reject unrecognised fields
- **THEN** that configuration SHALL be treated as a defect in the consumer, remedied by ignoring unknown fields and moving drift detection into a contract test

#### Scenario: An undocumented widening is still a contract violation

- **WHEN** forge ships a new response field without a MODIFIED delta on this spec, and every consumer tolerates it
- **THEN** the absence of a runtime failure SHALL NOT make the omission acceptable; the delta is still owed, and the contract is stale until it lands
