#!/usr/bin/env bash
# Validate openspec/specs/bounded-contexts/catalog.yaml.
# Spec: openspec/specs/bounded-contexts/spec.md.
# Asserts:
#   - exactly the ten expected contexts are listed
#   - every context name is lowercase kebab-case
#   - no owned_term appears under two distinct contexts
#   - every context declares responsibility and non_responsibilities
# Exits 0 on success, non-zero with a message on first failure.

set -euo pipefail

CATALOG="${CATALOG:-openspec/specs/bounded-contexts/catalog.yaml}"
EXPECTED_CONTEXTS=(gateway identity lexicon oracle forge cortex chronicle app deploy codex)

die() {
  printf 'validate-catalog: %s\n' "$*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || die "yq is required; install via 'brew install yq' or your package manager"
[ -r "$CATALOG" ] || die "cannot read catalog at $CATALOG"

# Collect actual context names from the catalog (sorted).
mapfile -t actual_contexts < <(yq -r '.contexts | keys | .[]' "$CATALOG" | sort)
expected_sorted=$(printf '%s\n' "${EXPECTED_CONTEXTS[@]}" | sort)

if [ "${#actual_contexts[@]}" -ne "${#EXPECTED_CONTEXTS[@]}" ]; then
  die "expected ${#EXPECTED_CONTEXTS[@]} contexts, found ${#actual_contexts[@]}"
fi

actual_joined=$(printf '%s\n' "${actual_contexts[@]}")
if [ "$actual_joined" != "$expected_sorted" ]; then
  die "context set mismatch; expected: $(printf '%s ' "${EXPECTED_CONTEXTS[@]}") got: ${actual_contexts[*]}"
fi

# Validate per-context structure and collect terms for uniqueness check.
declare -A term_owner
for ctx in "${actual_contexts[@]}"; do
  if ! printf '%s' "$ctx" | grep -Eq '^[a-z][a-z-]*$'; then
    die "context name '$ctx' is not lowercase kebab-case"
  fi

  responsibility=$(yq -r ".contexts.$ctx.responsibility // \"\"" "$CATALOG")
  [ -n "$responsibility" ] || die "context '$ctx' is missing responsibility"

  non_resp_count=$(yq -r ".contexts.$ctx.non_responsibilities | length" "$CATALOG")
  [ "$non_resp_count" -ge 1 ] || die "context '$ctx' must declare at least one non_responsibility"

  owned_count=$(yq -r ".contexts.$ctx.owned_terms | length" "$CATALOG")
  [ "$owned_count" -ge 1 ] || die "context '$ctx' must declare at least one owned_term"

  while IFS= read -r term; do
    [ -n "$term" ] || continue
    if [ -n "${term_owner[$term]:-}" ]; then
      die "owned_term '$term' is claimed by both '${term_owner[$term]}' and '$ctx'"
    fi
    term_owner[$term]=$ctx
  done < <(yq -r ".contexts.$ctx.owned_terms[]" "$CATALOG")
done

printf 'validate-catalog: OK — %d contexts, %d unique terms\n' "${#actual_contexts[@]}" "${#term_owner[@]}"
