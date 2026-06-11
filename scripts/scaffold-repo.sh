#!/usr/bin/env bash
# Scaffold a rbrain-* sibling repository from a runtime-scoped template.
# Spec: openspec/specs/scaffold-templates/spec.md, scaffold-procedure/spec.md.
#
# Usage:
#   bash scripts/scaffold-repo.sh <context-name> [<target-dir>] [--force]
#
#   <context-name>  Required. Must be an entry in openspec/specs/bounded-contexts/catalog.yaml
#                   whose runtime is one of rust|python|typescript.
#   <target-dir>    Optional. Defaults to ../rbrain-<context-name> relative to the codex root.
#   --force         Optional. Overwrite an existing non-empty target.
#
# The script resolves every substituted value from authoritative YAML sources
# under openspec/specs/. Command-line overrides for those values are rejected.
# After writing, it runs scripts/validate-repo.sh against the target.

set -euo pipefail

# ---- argument parsing -----------------------------------------------------
context=""
target=""
force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --force)
      force=1
      ;;
    --*)
      printf 'scaffold-repo: unknown flag %s\n' "$1" >&2
      exit 2
      ;;
    *)
      if [ -z "$context" ]; then
        context=$1
      elif [ -z "$target" ]; then
        target=$1
      else
        printf 'scaffold-repo: too many positional arguments\n' >&2
        exit 2
      fi
      ;;
  esac
  shift
done

[ -n "$context" ] || {
  printf 'scaffold-repo: usage: scaffold-repo.sh <context-name> [<target-dir>] [--force]\n' >&2
  exit 2
}

die() {
  printf 'scaffold-repo: %s\n' "$*" >&2
  exit 1
}

# ---- dependency checks ----------------------------------------------------
command -v yq >/dev/null 2>&1 || die "yq is required"
command -v envsubst >/dev/null 2>&1 || die "envsubst is required (install gettext)"

# ---- locate codex root ----------------------------------------------------
script_dir=$(cd "$(dirname "$0")" && pwd)
codex_root=$(cd "$script_dir/.." && pwd)

CATALOG="$codex_root/openspec/specs/bounded-contexts/catalog.yaml"
ALLOC="$codex_root/openspec/specs/language-runtimes/runtime-allocation.yaml"
BUDGETS="$codex_root/openspec/specs/language-runtimes/memory-budgets.yaml"
GRAPH="$codex_root/openspec/specs/service-topology/sync-graph.yaml"
TEMPLATES="$codex_root/openspec/specs/scaffold-templates/templates"

for f in "$CATALOG" "$ALLOC" "$BUDGETS" "$GRAPH"; do
  [ -r "$f" ] || die "cannot read required source: $f"
done

# ---- validate context against catalog -------------------------------------
if ! yq -e ".contexts.$context" "$CATALOG" >/dev/null 2>&1; then
  die "context '$context' is not in $CATALOG"
fi

# ---- default target -------------------------------------------------------
if [ -z "$target" ]; then
  target="$codex_root/../rbrain-$context"
fi

# ---- load values ----------------------------------------------------------
CONTEXT_NAME=$context
RUNTIME=$(yq -r ".allocation.$context // \"\"" "$ALLOC")
[ -n "$RUNTIME" ] || die "runtime-allocation.yaml missing entry for '$context'"
case "$RUNTIME" in
  rust|python|typescript) ;;
  none) die "context '$context' has runtime=none; not scaffoldable" ;;
  *) die "runtime-allocation.yaml entry for '$context' is invalid: $RUNTIME" ;;
esac

MAX_RSS_MB=$(yq -r ".budgets.$context" "$BUDGETS")
printf '%s' "$MAX_RSS_MB" | grep -Eq '^[0-9]+$' || die "memory-budgets.yaml entry for '$context' is invalid: $MAX_RSS_MB"

RESPONSIBILITY=$(yq -r ".contexts.$context.responsibility" "$CATALOG")
[ -n "$RESPONSIBILITY" ] && [ "$RESPONSIBILITY" != "null" ] || die "catalog.yaml missing responsibility for '$context'"
# Trim trailing newline that yq adds for folded scalars
RESPONSIBILITY=$(printf '%s' "$RESPONSIBILITY" | tr -d '\n')

# ---- list expansion helpers ----------------------------------------------
# bullet_list: read each item from a yq query, prefix with "- " and join with newlines.
#              Empty list => "(none)".
bullet_list() {
  local path=$1 file=$2
  local out=""
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    [ "$item" = "null" ] && continue
    if [ -z "$out" ]; then
      out="- $item"
    else
      out="$out"$'\n'"- $item"
    fi
  done < <(yq -r "$path" "$file" 2>/dev/null || true)
  if [ -z "$out" ]; then
    out="(none)"
  fi
  printf '%s' "$out"
}

# yaml_inline: read items from a yq query, produce inline YAML "[a, b]" or "[]".
yaml_inline() {
  local path=$1 file=$2
  local items=""
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    [ "$item" = "null" ] && continue
    if [ -z "$items" ]; then
      items="$item"
    else
      items="$items, $item"
    fi
  done < <(yq -r "$path" "$file" 2>/dev/null || true)
  if [ -z "$items" ]; then
    printf '[]'
  else
    printf '[%s]' "$items"
  fi
}

NON_RESPONSIBILITIES=$(bullet_list ".contexts.$context.non_responsibilities[]?" "$CATALOG")
OWNED_TERMS=$(bullet_list ".contexts.$context.owned_terms[]?" "$CATALOG")
CALLERS=$(bullet_list ".edges[] | select(.callee == \"$context\") | .caller" "$GRAPH")
CALLEES=$(bullet_list ".edges[] | select(.caller == \"$context\") | .callee" "$GRAPH")
PUBLISHES="(none)"   # Future: derive from OWNERSHIP.publishes once siblings declare them

DEPENDS_ON_INLINE=$(yaml_inline ".edges[] | select(.caller == \"$context\") | .callee" "$GRAPH")
PUBLISHES_INLINE='[]'

export CONTEXT_NAME RUNTIME MAX_RSS_MB RESPONSIBILITY \
       NON_RESPONSIBILITIES OWNED_TERMS CALLERS CALLEES PUBLISHES \
       DEPENDS_ON_INLINE PUBLISHES_INLINE

# ---- select template -------------------------------------------------------
template_dir="$TEMPLATES/${RUNTIME}-service"
case "$RUNTIME" in
  typescript) template_dir="$TEMPLATES/typescript-app" ;;
esac
[ -d "$template_dir" ] || die "template directory not found: $template_dir"

# ---- target dir guard ------------------------------------------------------
if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
  if [ "$force" -ne 1 ]; then
    die "target '$target' exists and is non-empty; pass --force to overwrite template-managed files"
  fi
fi
mkdir -p "$target"

# ---- substitute and write --------------------------------------------------
allowlist='$CONTEXT_NAME $RUNTIME $MAX_RSS_MB $RESPONSIBILITY $NON_RESPONSIBILITIES $OWNED_TERMS $CALLERS $CALLEES $PUBLISHES $DEPENDS_ON_INLINE $PUBLISHES_INLINE'

# Walk every file under template_dir, preserving the relative path.
(
  cd "$template_dir"
  find . -type f -print0
) | while IFS= read -r -d '' rel; do
  src="$template_dir/$rel"
  dst="$target/$rel"
  mkdir -p "$(dirname "$dst")"
  envsubst "$allowlist" < "$src" > "$dst"
done

# Preserve executable bits if any (templates currently have none).

# ---- post-scaffold validation ---------------------------------------------
if ! CODEX_LOCAL_ROOT="$codex_root" bash "$codex_root/scripts/validate-repo.sh" "$target" >/tmp/scaffold-validate.log 2>&1; then
  printf 'scaffold-repo: validate-repo failed against %s:\n' "$target" >&2
  cat /tmp/scaffold-validate.log >&2
  exit 1
fi

printf 'scaffold-repo: OK — wrote %s (runtime=%s, budget=%s MB)\n' "$target" "$RUNTIME" "$MAX_RSS_MB"
printf 'scaffold-repo: next steps in openspec/specs/scaffold-procedure/checklist.md\n'
