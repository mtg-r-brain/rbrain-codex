#!/usr/bin/env bash
# Validate openspec/specs/service-topology/sync-graph.yaml.
# Spec: openspec/specs/service-topology/spec.md.
# Asserts:
#   - every node referenced (caller/callee) is a valid catalog entry
#   - the graph is a DAG (no cycles)
#   - every edge declares a non-empty purpose
# Exits 0 on success, non-zero with a message on first failure.

set -euo pipefail

CATALOG="${CATALOG:-openspec/specs/bounded-contexts/catalog.yaml}"
GRAPH="${GRAPH:-openspec/specs/service-topology/sync-graph.yaml}"

die() {
  printf 'validate-topology: %s\n' "$*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || die "yq is required"
command -v tsort >/dev/null 2>&1 || die "tsort is required (POSIX utility)"
[ -r "$CATALOG" ] || die "cannot read catalog at $CATALOG"
[ -r "$GRAPH" ] || die "cannot read sync-graph at $GRAPH"

# Build the set of valid context names.
mapfile -t known_contexts < <(yq -r '.contexts | keys | .[]' "$CATALOG")
is_known() {
  local needle=$1
  for c in "${known_contexts[@]}"; do
    [ "$c" = "$needle" ] && return 0
  done
  return 1
}

edge_count=$(yq -r '.edges | length' "$GRAPH")
[ "$edge_count" -ge 1 ] || die "sync-graph.yaml declares no edges"

# Validate each edge and feed (caller, callee) pairs to tsort.
edges_for_tsort=""
for i in $(seq 0 $((edge_count - 1))); do
  caller=$(yq -r ".edges[$i].caller" "$GRAPH")
  callee=$(yq -r ".edges[$i].callee" "$GRAPH")
  purpose=$(yq -r ".edges[$i].purpose // \"\"" "$GRAPH")

  [ -n "$caller" ] && [ "$caller" != "null" ] || die "edge[$i] missing caller"
  [ -n "$callee" ] && [ "$callee" != "null" ] || die "edge[$i] missing callee"
  [ -n "$purpose" ] || die "edge[$i] ($caller -> $callee) missing purpose"

  is_known "$caller" || die "edge[$i] caller '$caller' is not in catalog.yaml"
  is_known "$callee" || die "edge[$i] callee '$callee' is not in catalog.yaml"
  [ "$caller" != "$callee" ] || die "edge[$i] self-loop on '$caller' is not allowed"

  edges_for_tsort+="$caller $callee"$'\n'
done

# tsort exits non-zero AND emits a "cycle" diagnostic on cyclic input.
if ! printf '%s' "$edges_for_tsort" | tsort >/dev/null 2>&1; then
  printf '%s' "$edges_for_tsort" | tsort 2>&1 || true
  die "sync graph is not a DAG"
fi

printf 'validate-topology: OK — %d edges, DAG verified\n' "$edge_count"
