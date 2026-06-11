# LlmPort capability contract

Reference document. The normative requirement lives in
`openspec/specs/llm-abstraction/spec.md` ("LlmPort exposes generation,
tool-calling, and embeddings").

This document describes the three capabilities `LlmPort` exposes, in prose,
without committing to method signatures or types. The signatures are an
implementation detail of `rbrain-cortex`; this document is the contract that
any provider implementation MUST satisfy and any caller MAY rely on.

## Capability 1 — Generation

Given a prompt (system instructions + a conversation history of alternating
user and assistant turns), the port produces a free-form textual response.

Inputs the caller provides:

- A system instruction (text).
- A list of prior turns. Each turn carries a role (`user` or `assistant`) and
  a content payload (text).
- Sampling parameters (temperature, max tokens) — the port MAY accept these
  as optional and apply provider-specific defaults when absent.

Outputs the port returns:

- A text response.
- Metadata about the generation (input/output token counts, stop reason,
  provider-specific identifiers) — the exact metadata shape is left to the
  implementation but MUST be opaque to the caller (treated as a passthrough
  to telemetry / logs).

The generation capability is the minimum any provider MUST support. A
provider that cannot generate text is not a valid `LlmPort`.

## Capability 2 — Tool-calling

Given a prompt, a conversation history, and a list of tool descriptors, the
port produces a decision on whether to call a tool, which tool, and with
what arguments.

Inputs the caller provides:

- Everything from the generation capability.
- A list of tool descriptors. Each descriptor names a tool, describes its
  purpose, and declares the shape of its arguments (JSON schema).

Outputs the port returns:

- Either a textual response (the model chose to answer directly), or
- One or more tool invocations. Each invocation names a tool and carries
  arguments that match the descriptor's schema.
- The same metadata block as the generation capability.

This capability MUST exist for every provider that ships in `rbrain-cortex`.
A provider whose underlying API does not natively support function-calling
SHALL emulate the contract (e.g. via structured-output prompting) or SHALL
fail at boot with a clear error.

## Capability 3 — Embeddings

Given a batch of texts, the port produces a dense vector embedding per
input.

Inputs the caller provides:

- A list of texts (1 to N entries).
- An optional embedding-model selector — the port MAY ignore it and use the
  provider's default embedding model.

Outputs the port returns:

- A list of vectors, one per input, in the same order as the input.
- Vector dimensionality is provider-dependent; callers MUST query the port
  for the dimension before persisting embeddings.

If a provider does not have a native embeddings endpoint, the provider
implementation SHALL fail at boot when embeddings are requested. The boot
failure SHALL name the missing capability so the operator can either switch
providers or configure a separate embeddings provider in a future change.

## Cross-cutting expectations

These apply to every capability above.

- **No streaming exposed at v1.** The port returns full responses; streaming
  is deferred to a future spec.
- **Errors are structured.** Network failures, quota exhaustion, content
  policy denials, and provider outages MUST raise structured errors the
  caller can branch on. Generic exceptions are forbidden.
- **No retries inside the port.** Retry logic lives one layer above
  (orchestration policy). The port is a thin contract on top of provider
  SDKs.
- **No prompt mutation inside the port.** Whatever the caller passes in is
  what the provider sees, modulo strictly required format adaptation (e.g.
  rewriting the message list shape for the provider's SDK).
