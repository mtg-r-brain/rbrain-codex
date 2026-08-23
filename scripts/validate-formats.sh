#!/usr/bin/env bash
# Validate the platform format catalog and its consuming surfaces.
# Spec: openspec/specs/format-catalog/spec.md.
#
# Usage:
#   bash validate-formats.sh              # self mode
#   bash validate-formats.sh <repo-path>  # sibling mode (context from OWNERSHIP.yaml)
#
# Self mode asserts:
#   - formats.yaml is a non-empty list of unique ids matching ^[a-z][a-z0-9]*$
#   - forge-api/spec.md's accepted-identifiers enumeration equals the catalog
# Sibling mode asserts, per the repo's OWNERSHIP.yaml context:
#   - lexicon: src/legality.rs        FORMATS equals the catalog as a set
#   - forge:   src/legality_store.rs  FORMATS equals the catalog as a set
#   - codex:   falls through to self mode
#   Any other context fails loudly — no silent no-op on mis-wiring.
#
# The catalog resolves relative to this script's own location, so the same
# invocation works from a sibling checkout (../rbrain-codex) and from a CI
# checkout path (.codex). Override with FORMATS_FILE.
# Deliberately bash-3.2-compatible (no mapfile, no declare -A): unlike the
# CI-only validators this one is part of the documented local gate sequence
# on contributor macOS.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
CODEX_ROOT=$(dirname "$SCRIPT_DIR")
FORMATS_FILE="${FORMATS_FILE:-$CODEX_ROOT/openspec/specs/format-catalog/formats.yaml}"

die() {
  printf 'validate-formats: %s\n' "$*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || die "yq is required; install via 'brew install yq' or your package manager"
[ -r "$FORMATS_FILE" ] || die "cannot read catalog at $FORMATS_FILE"

catalog=$(yq -r '.formats[]?' "$FORMATS_FILE")
[ -n "$catalog" ] || die "catalog lists no formats"

while IFS= read -r fmt; do
  printf '%s' "$fmt" | grep -Eq '^[a-z][a-z0-9]*$' \
    || die "format identifier '$fmt' does not match ^[a-z][a-z0-9]*$"
done <<EOF
$catalog
EOF

catalog_sorted=$(printf '%s\n' "$catalog" | sort)
dupes=$(printf '%s\n' "$catalog_sorted" | uniq -d)
[ -z "$dupes" ] || die "catalog contains duplicate identifiers: $(printf '%s ' $dupes)"

# Compare a surface's identifier list to the catalog as a set.
compare_sets() {
  label=$1
  actual_sorted=$(printf '%s\n' "$2" | sort -u)
  if [ "$actual_sorted" != "$catalog_sorted" ]; then
    missing=$(comm -23 <(printf '%s\n' "$catalog_sorted") <(printf '%s\n' "$actual_sorted") | tr '\n' ' ')
    extra=$(comm -13 <(printf '%s\n' "$catalog_sorted") <(printf '%s\n' "$actual_sorted") | tr '\n' ' ')
    die "$label diverges from the catalog; missing: ${missing:-none}; extra: ${extra:-none}"
  fi
}

check_rust_const() {
  src=$1
  [ -r "$src" ] || die "cannot read $src"
  consts=$(awk '/pub const FORMATS/{f=1} f{print} f&&/\];/{exit}' "$src" \
    | grep -oE '"[a-z][a-z0-9]*"' | tr -d '"')
  [ -n "$consts" ] || die "could not extract a FORMATS constant from $src"
  compare_sets "FORMATS in $src" "$consts"
}

check_forge_api_prose() {
  spec="$CODEX_ROOT/openspec/specs/forge-api/spec.md"
  [ -r "$spec" ] || die "cannot read $spec"
  anchor='accepted `format` identifiers\*\* are exactly: '
  n=$(grep -cE "$anchor" "$spec" || true)
  [ "$n" = "1" ] || die "expected exactly one accepted-identifiers enumeration in $spec, found $n"
  enum=$(grep -E "$anchor" "$spec" \
    | sed -e 's/^.*are exactly: //' -e 's/\. .*$//' \
    | grep -oE '`[a-z][a-z0-9]*`' | tr -d '`')
  [ -n "$enum" ] || die "could not extract identifiers from the enumeration in $spec"
  compare_sets "forge-api accepted-identifiers enumeration" "$enum"
}

REPO_PATH="${1:-}"
context=codex
if [ -n "$REPO_PATH" ]; then
  [ -d "$REPO_PATH" ] || die "repo path '$REPO_PATH' is not a directory"
  [ -r "$REPO_PATH/OWNERSHIP.yaml" ] || die "missing $REPO_PATH/OWNERSHIP.yaml"
  context=$(yq -r '.context' "$REPO_PATH/OWNERSHIP.yaml")
fi

case "$context" in
  codex)
    check_forge_api_prose
    ;;
  lexicon)
    check_rust_const "$REPO_PATH/src/legality.rs"
    ;;
  forge)
    check_rust_const "$REPO_PATH/src/legality_store.rs"
    ;;
  *)
    die "context '$context' has no registered format surface; register it here before wiring CI"
    ;;
esac

count=$(printf '%s\n' "$catalog" | wc -l | tr -d ' ')
printf 'validate-formats: OK — context=%s, %s formats\n' "$context" "$count"
