#!/usr/bin/env bash
# Validate a rbrain-* repository against repository-conventions.
# Spec: openspec/specs/repository-conventions/spec.md.
# Usage: bash validate-repo.sh [<repo-path>]
#   <repo-path> defaults to the current working directory.
#
# Asserts:
#   - presence of README.md, AGENTS.md, OWNERSHIP.yaml, .github/workflows/ci.yml
#   - OWNERSHIP.yaml carries the six mandatory fields with valid values
#   - runtime matches language-runtimes/runtime-allocation.yaml
#   - max_rss_mb matches language-runtimes/memory-budgets.yaml
#   - depends_on entries are callees declared in sync-graph.yaml for this context
#   - publishes patterns match rbrain.<this-context>.<event> (or rbrain.system.<event>
#     for deploy)
#
# Looks up catalog/topology/runtime YAMLs in this order:
#   1. Local files under $REPO_PATH/../rbrain-codex/openspec/specs/ if present
#   2. Files fetched from $CODEX_RAW_BASE if curl is available
#   3. Override path via $CODEX_LOCAL_ROOT
# Defaults assume the canonical layout where rbrain-codex sits alongside the
# repo being validated.

set -euo pipefail

CODEX_RAW_BASE="${CODEX_RAW_BASE:-https://raw.githubusercontent.com/mtg-r-brain/rbrain-codex/main}"
REPO_PATH="${1:-.}"

die() {
  printf 'validate-repo: %s\n' "$*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || die "yq is required"
[ -d "$REPO_PATH" ] || die "repo path '$REPO_PATH' is not a directory"

# Mandatory files
for f in README.md AGENTS.md OWNERSHIP.yaml .github/workflows/ci.yml; do
  [ -r "$REPO_PATH/$f" ] || die "missing mandatory file: $f"
done

# Resolve codex sources
codex_root=""
if [ -n "${CODEX_LOCAL_ROOT:-}" ]; then
  codex_root="$CODEX_LOCAL_ROOT"
elif [ -d "$REPO_PATH/../rbrain-codex/openspec/specs" ]; then
  codex_root="$REPO_PATH/../rbrain-codex"
elif [ -d "$REPO_PATH/openspec/specs" ]; then
  # The repo being validated is rbrain-codex itself.
  codex_root="$REPO_PATH"
fi

tmp_codex=""
fetch_codex_file() {
  local rel=$1
  if [ -n "$codex_root" ] && [ -r "$codex_root/$rel" ]; then
    printf '%s' "$codex_root/$rel"
    return
  fi
  command -v curl >/dev/null 2>&1 || die "no local codex and curl unavailable; set CODEX_LOCAL_ROOT or install curl"
  if [ -z "$tmp_codex" ]; then
    tmp_codex=$(mktemp -d)
    trap 'rm -rf "$tmp_codex"' EXIT
  fi
  mkdir -p "$tmp_codex/$(dirname "$rel")"
  curl -fsSL "$CODEX_RAW_BASE/$rel" -o "$tmp_codex/$rel" \
    || die "failed to fetch $rel from $CODEX_RAW_BASE"
  printf '%s' "$tmp_codex/$rel"
}

CATALOG=$(fetch_codex_file openspec/specs/bounded-contexts/catalog.yaml)
GRAPH=$(fetch_codex_file openspec/specs/service-topology/sync-graph.yaml)
# These two are produced by technology-stack's apply; allow absence for now.
RUNTIME_ALLOC=""
MEM_BUDGETS=""
if [ -n "$codex_root" ] && [ -r "$codex_root/openspec/specs/language-runtimes/runtime-allocation.yaml" ]; then
  RUNTIME_ALLOC="$codex_root/openspec/specs/language-runtimes/runtime-allocation.yaml"
fi
if [ -n "$codex_root" ] && [ -r "$codex_root/openspec/specs/language-runtimes/memory-budgets.yaml" ]; then
  MEM_BUDGETS="$codex_root/openspec/specs/language-runtimes/memory-budgets.yaml"
fi

OWNERSHIP="$REPO_PATH/OWNERSHIP.yaml"

# Mandatory fields
for field in context owner runtime max_rss_mb depends_on publishes; do
  raw=$(yq -r ".$field // \"\"" "$OWNERSHIP")
  [ -n "$raw" ] && [ "$raw" != "null" ] || die "OWNERSHIP.yaml missing required field '$field'"
done

context=$(yq -r '.context' "$OWNERSHIP")
runtime=$(yq -r '.runtime' "$OWNERSHIP")
max_rss=$(yq -r '.max_rss_mb' "$OWNERSHIP")

# Context exists in catalog
if ! yq -e ".contexts.$context" "$CATALOG" >/dev/null 2>&1; then
  die "OWNERSHIP.yaml context '$context' is not in catalog.yaml"
fi

# Runtime is one of the allowed values
case "$runtime" in
  rust|python|typescript|none) ;;
  *) die "OWNERSHIP.yaml runtime '$runtime' is invalid; allowed: rust|python|typescript|none" ;;
esac

# max_rss_mb is an integer; 0 iff runtime=none
if ! printf '%s' "$max_rss" | grep -Eq '^[0-9]+$'; then
  die "OWNERSHIP.yaml max_rss_mb '$max_rss' is not a non-negative integer"
fi
if [ "$runtime" = "none" ] && [ "$max_rss" -ne 0 ]; then
  die "OWNERSHIP.yaml max_rss_mb must be 0 when runtime=none (got $max_rss)"
fi
if [ "$runtime" != "none" ] && [ "$max_rss" -eq 0 ]; then
  die "OWNERSHIP.yaml max_rss_mb must be >0 when runtime!=none"
fi

# Cross-check runtime against runtime-allocation.yaml if available
if [ -n "$RUNTIME_ALLOC" ]; then
  expected_runtime=$(yq -r ".allocation.$context // \"\"" "$RUNTIME_ALLOC")
  if [ -n "$expected_runtime" ] && [ "$expected_runtime" != "$runtime" ]; then
    die "OWNERSHIP.yaml runtime '$runtime' for context '$context' does not match runtime-allocation.yaml ('$expected_runtime')"
  fi
fi

# Cross-check max_rss_mb against memory-budgets.yaml if available
if [ -n "$MEM_BUDGETS" ]; then
  expected_budget=$(yq -r ".budgets.$context // \"\"" "$MEM_BUDGETS")
  if [ -n "$expected_budget" ] && [ "$expected_budget" != "$max_rss" ]; then
    die "OWNERSHIP.yaml max_rss_mb '$max_rss' for context '$context' does not match memory-budgets.yaml ('$expected_budget')"
  fi
fi

# depends_on: every entry MUST be a callee for this context in sync-graph.yaml
allowed_callees=$(yq -r ".edges[] | select(.caller == \"$context\") | .callee" "$GRAPH" | sort -u)
while IFS= read -r dep; do
  [ -n "$dep" ] || continue
  if [ "$dep" = "null" ]; then continue; fi
  if ! printf '%s\n' "$allowed_callees" | grep -qx "$dep"; then
    die "OWNERSHIP.yaml depends_on '$dep' is not a declared callee for '$context' in sync-graph.yaml"
  fi
done < <(yq -r '.depends_on[]?' "$OWNERSHIP")

# publishes: every entry matches the naming convention
if [ "$context" = "deploy" ]; then
  pubre='^rbrain\.(deploy|system)\.[a-z][a-z0-9-]*$'
else
  pubre="^rbrain\\.${context}\\.[a-z][a-z0-9-]*$"
fi
while IFS= read -r subj; do
  [ -n "$subj" ] || continue
  if [ "$subj" = "null" ]; then continue; fi
  if ! printf '%s' "$subj" | grep -Eq "$pubre"; then
    die "OWNERSHIP.yaml publishes '$subj' does not match $pubre"
  fi
done < <(yq -r '.publishes[]?' "$OWNERSHIP")

printf 'validate-repo: OK — context=%s runtime=%s max_rss_mb=%s\n' "$context" "$runtime" "$max_rss"
