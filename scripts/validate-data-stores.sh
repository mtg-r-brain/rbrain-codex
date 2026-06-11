#!/usr/bin/env bash
# Validate openspec/specs/data-stores/postgres-roles.yaml.
# Spec: openspec/specs/data-stores/spec.md.
# Asserts:
#   - the five persistent contexts (identity, lexicon, oracle, forge,
#     chronicle) each have a role declared
#   - each role's schema matches its own name (single-schema ownership)
#   - each role holds USAGE plus DML privileges (SELECT/INSERT/UPDATE/DELETE)
#   - no role declares superuser: true
#   - cross_schema list is empty for every role
# Exits 0 on success, non-zero with a message on first failure.

set -euo pipefail

ROLES="${ROLES:-openspec/specs/data-stores/postgres-roles.yaml}"
EXPECTED_ROLES=(identity lexicon oracle forge chronicle)
REQUIRED_PRIVS=(USAGE SELECT INSERT UPDATE DELETE)

die() {
  printf 'validate-data-stores: %s\n' "$*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || die "yq is required"
[ -r "$ROLES" ] || die "cannot read $ROLES"

mapfile -t actual < <(yq -r '.roles | keys | .[]' "$ROLES" | sort)
expected_sorted=$(printf '%s\n' "${EXPECTED_ROLES[@]}" | sort)
actual_joined=$(printf '%s\n' "${actual[@]}")

if [ "$actual_joined" != "$expected_sorted" ]; then
  die "role set mismatch; expected: ${EXPECTED_ROLES[*]} got: ${actual[*]}"
fi

for role in "${actual[@]}"; do
  schema=$(yq -r ".roles.$role.schema" "$ROLES")
  [ "$schema" = "$role" ] || die "role '$role' owns schema '$schema'; must own '$role'"

  superuser=$(yq -r ".roles.$role.superuser" "$ROLES")
  [ "$superuser" = "false" ] || die "role '$role' must declare superuser: false"

  cross=$(yq -r ".roles.$role.cross_schema | length" "$ROLES")
  [ "$cross" = "0" ] || die "role '$role' must declare cross_schema: [] (no cross-schema grants)"

  mapfile -t privs < <(yq -r ".roles.$role.privileges[]" "$ROLES")
  for required in "${REQUIRED_PRIVS[@]}"; do
    found=0
    for p in "${privs[@]}"; do
      [ "$p" = "$required" ] && { found=1; break; }
    done
    [ "$found" = 1 ] || die "role '$role' missing required privilege '$required'"
  done
done

printf 'validate-data-stores: OK — %d roles, schema-per-context enforced\n' "${#actual[@]}"
