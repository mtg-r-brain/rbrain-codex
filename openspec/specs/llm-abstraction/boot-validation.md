# Boot-time validation of LLM configuration

Reference document. The normative requirement lives in
`openspec/specs/llm-abstraction/spec.md` ("No default provider; explicit
configuration required").

This document describes the contract for how `rbrain-cortex` MUST behave at
startup with respect to LLM provider configuration. The intent is to fail
fast and noisily when the operator has misconfigured the deployment, rather
than producing a service that listens on its port but returns errors on the
first inference request.

## No default

`rbrain-cortex` SHALL NOT carry a default value for the `LLM_PROVIDER`
environment variable. The choice of LLM provider is a deployment-level
concern with cost, latency, and quality implications; defaulting to any of
the three reference providers would silently mislead operators.

## Boot sequence

At process startup, before binding any port, `rbrain-cortex` MUST execute
the following sequence:

1. **Read `LLM_PROVIDER`.** If unset, exit non-zero with a clear error
   message that lists the accepted values (`claude`, `ollama`, `openai`,
   sourced from `providers.yaml`).
2. **Reject unknown providers.** If the value is set but is not one of the
   accepted values, exit non-zero with the same message and naming the
   invalid value.
3. **Resolve the provider implementation.** Look up the matching provider
   under `providers.yaml`. Fail if the entry is missing (would indicate a
   `providers.yaml` drift).
4. **Validate required env vars.** Iterate the provider's `env.required`
   list. For each missing required variable, accumulate the missing name.
   If at least one is missing, exit non-zero with a message listing every
   missing variable and pointing at `providers.yaml`.
5. **Instantiate the provider.** Call the provider's constructor with the
   validated env vars. Any provider-specific instantiation failure
   (unreachable Ollama endpoint, invalid Anthropic key format) SHALL also
   surface as a non-zero exit.
6. **Bind the application port.** Only when steps 1–5 succeed.

A boot failure SHALL produce an exit code distinct from a normal shutdown
(non-zero, typically `1` or `78` for `EX_CONFIG`). The exit message SHALL
be written to stderr.

## Examples of the expected operator experience

Missing `LLM_PROVIDER`:

```
$ rbrain-cortex
[FATAL] LLM_PROVIDER is not set. Set it to one of: claude, ollama, openai.
        See openspec/specs/llm-abstraction/providers.yaml in rbrain-codex.
$ echo $?
1
```

Misspelled provider:

```
$ LLM_PROVIDER=anthropic rbrain-cortex
[FATAL] LLM_PROVIDER='anthropic' is not a recognized provider.
        Accepted values: claude, ollama, openai.
$ echo $?
1
```

Provider chosen, key missing:

```
$ LLM_PROVIDER=claude rbrain-cortex
[FATAL] Provider 'claude' requires environment variable ANTHROPIC_API_KEY.
        Missing: ANTHROPIC_API_KEY.
        See openspec/specs/llm-abstraction/providers.yaml in rbrain-codex.
$ echo $?
1
```

Happy path:

```
$ LLM_PROVIDER=claude ANTHROPIC_API_KEY=sk-... rbrain-cortex
[INFO] LlmPort initialised with provider=claude (sdk=anthropic).
[INFO] Listening on 0.0.0.0:8080.
```
