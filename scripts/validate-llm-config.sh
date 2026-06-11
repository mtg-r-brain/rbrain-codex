#!/usr/bin/env bash
# Validate openspec/specs/llm-abstraction/providers.yaml.
# Spec: openspec/specs/llm-abstraction/spec.md.
# Asserts:
#   - exactly three providers are declared
#   - the three provider names match {claude, ollama, openai}
#   - every provider declares an sdk identifier
#   - every provider declares at least one required env var
# Exits 0 on success, non-zero with a message on first failure.

set -euo pipefail

PROVIDERS="${PROVIDERS:-openspec/specs/llm-abstraction/providers.yaml}"
EXPECTED=(claude ollama openai)

die() {
  printf 'validate-llm-config: %s\n' "$*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || die "yq is required"
[ -r "$PROVIDERS" ] || die "cannot read $PROVIDERS"

mapfile -t actual < <(yq -r '.providers | keys | .[]' "$PROVIDERS" | sort)
expected_sorted=$(printf '%s\n' "${EXPECTED[@]}" | sort)
actual_joined=$(printf '%s\n' "${actual[@]}")

if [ "${#actual[@]}" -ne 3 ]; then
  die "expected exactly 3 providers, found ${#actual[@]}"
fi
if [ "$actual_joined" != "$expected_sorted" ]; then
  die "provider set mismatch; expected: ${EXPECTED[*]} got: ${actual[*]}"
fi

for p in "${actual[@]}"; do
  sdk=$(yq -r ".providers.$p.sdk // \"\"" "$PROVIDERS")
  [ -n "$sdk" ] || die "provider '$p' missing sdk identifier"

  required_count=$(yq -r ".providers.$p.env.required | length" "$PROVIDERS")
  [ "$required_count" -ge 1 ] || die "provider '$p' must declare at least one required env var"
done

printf 'validate-llm-config: OK — %d providers (%s)\n' "${#actual[@]}" "${actual[*]}"
