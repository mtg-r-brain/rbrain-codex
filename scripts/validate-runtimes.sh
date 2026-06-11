#!/usr/bin/env bash
# Validate openspec/specs/language-runtimes/{runtime-allocation,version-floors,memory-budgets}.yaml.
# Spec: openspec/specs/language-runtimes/spec.md.
# Asserts:
#   - every catalog context is present in runtime-allocation.yaml
#   - every runtime value is one of {rust, python, typescript, none}
#   - every catalog context is present in memory-budgets.yaml
#   - max_rss_mb is 0 iff runtime is none
#   - sum of per-context budgets + external budgets does not exceed the ceiling
#   - version-floors.yaml carries the expected component keys
# Exits 0 on success, non-zero with a message on first failure.

set -euo pipefail

CATALOG="${CATALOG:-openspec/specs/bounded-contexts/catalog.yaml}"
ALLOC="${ALLOC:-openspec/specs/language-runtimes/runtime-allocation.yaml}"
BUDGETS="${BUDGETS:-openspec/specs/language-runtimes/memory-budgets.yaml}"
FLOORS="${FLOORS:-openspec/specs/language-runtimes/version-floors.yaml}"

EXPECTED_FLOORS=(rust python node nextjs axum tokio sqlx fastapi langgraph)

die() {
  printf 'validate-runtimes: %s\n' "$*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || die "yq is required"
for f in "$CATALOG" "$ALLOC" "$BUDGETS" "$FLOORS"; do
  [ -r "$f" ] || die "cannot read $f"
done

mapfile -t contexts < <(yq -r '.contexts | keys | .[]' "$CATALOG")

# Runtime allocation: every context present, valid runtime
for ctx in "${contexts[@]}"; do
  rt=$(yq -r ".allocation.$ctx // \"\"" "$ALLOC")
  [ -n "$rt" ] || die "runtime-allocation.yaml missing entry for context '$ctx'"
  case "$rt" in
    rust|python|typescript|none) ;;
    *) die "runtime-allocation.yaml entry for '$ctx' is '$rt'; allowed: rust|python|typescript|none" ;;
  esac
done

# Memory budgets: every context present, type/coherence check
total_services=0
for ctx in "${contexts[@]}"; do
  budget=$(yq -r ".budgets.$ctx // \"\"" "$BUDGETS")
  [ -n "$budget" ] || die "memory-budgets.yaml missing entry for context '$ctx'"
  if ! printf '%s' "$budget" | grep -Eq '^[0-9]+$'; then
    die "memory-budgets.yaml entry for '$ctx' is '$budget'; expected non-negative integer"
  fi

  rt=$(yq -r ".allocation.$ctx" "$ALLOC")
  if [ "$rt" = "none" ] && [ "$budget" -ne 0 ]; then
    die "memory-budgets.yaml '$ctx' budget must be 0 when runtime=none (got $budget)"
  fi
  if [ "$rt" != "none" ] && [ "$budget" -eq 0 ]; then
    die "memory-budgets.yaml '$ctx' budget must be >0 when runtime!=none"
  fi
  total_services=$((total_services + budget))
done

# External budgets
ext_postgres=$(yq -r '.external.postgres' "$BUDGETS")
ext_redis=$(yq -r '.external.redis' "$BUDGETS")
ext_nats=$(yq -r '.external.nats' "$BUDGETS")
for v in "$ext_postgres" "$ext_redis" "$ext_nats"; do
  printf '%s' "$v" | grep -Eq '^[0-9]+$' || die "memory-budgets.yaml external budgets must be non-negative integers"
done
total_external=$((ext_postgres + ext_redis + ext_nats))

ceiling=$(yq -r '.ceiling' "$BUDGETS")
printf '%s' "$ceiling" | grep -Eq '^[0-9]+$' || die "memory-budgets.yaml ceiling must be a non-negative integer"

grand=$((total_services + total_external))
if [ "$grand" -gt "$ceiling" ]; then
  die "platform memory total ${grand} MB exceeds ceiling ${ceiling} MB (services ${total_services} MB + external ${total_external} MB)"
fi

# Version floors: every expected key present
for key in "${EXPECTED_FLOORS[@]}"; do
  v=$(yq -r ".floors.$key // \"\"" "$FLOORS")
  [ -n "$v" ] || die "version-floors.yaml missing entry for '$key'"
done

printf 'validate-runtimes: OK — %d contexts, services %d MB + external %d MB = %d / %d MB ceiling\n' \
  "${#contexts[@]}" "$total_services" "$total_external" "$grand" "$ceiling"
