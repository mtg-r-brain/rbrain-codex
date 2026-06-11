#!/usr/bin/env bash
# Validate NATS subject patterns declared in any OWNERSHIP.yaml file found
# under the current worktree.
# Spec: openspec/specs/messaging-runtime/spec.md
#       openspec/specs/service-topology/spec.md
#
# For each OWNERSHIP.yaml the script finds, every entry in `publishes` MUST
# match either:
#   ^rbrain\.<this-context>\.[a-z][a-z0-9-]*$
# or (only when this-context == deploy):
#   ^rbrain\.system\.[a-z][a-z0-9-]*$
#
# Exits 0 on success, non-zero with a message on first failure.
# Notes: scaffolded sibling repos run a stricter check via validate-repo.sh
# in their own CI. This script provides codex-local coverage for any
# OWNERSHIP.yaml committed in this repo (currently codex's own).

set -euo pipefail

die() {
  printf 'validate-subjects: %s\n' "$*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || die "yq is required"

# Find every OWNERSHIP.yaml in the worktree, skipping anything under
# templates/, baselines/, or archive/ which carry placeholders or historical
# snapshots respectively.
mapfile -t files < <(
  find . -type f -name OWNERSHIP.yaml \
    -not -path '*/templates/*' \
    -not -path '*/baselines/*' \
    -not -path '*/archive/*' \
    -not -path '*/.git/*'
)

if [ "${#files[@]}" -eq 0 ]; then
  printf 'validate-subjects: no OWNERSHIP.yaml found in worktree — nothing to check\n'
  exit 0
fi

total=0
for f in "${files[@]}"; do
  ctx=$(yq -r '.context // ""' "$f")
  [ -n "$ctx" ] || die "$f missing .context"

  if [ "$ctx" = "deploy" ]; then
    pubre='^rbrain\.(deploy|system)\.[a-z][a-z0-9-]*$'
  else
    pubre="^rbrain\\.${ctx}\\.[a-z][a-z0-9-]*$"
  fi

  while IFS= read -r subj; do
    [ -n "$subj" ] || continue
    [ "$subj" = "null" ] && continue
    if ! printf '%s' "$subj" | grep -Eq "$pubre"; then
      die "$f: subject '$subj' does not match $pubre"
    fi
    total=$((total + 1))
  done < <(yq -r '.publishes[]?' "$f")
done

printf 'validate-subjects: OK — %d OWNERSHIP.yaml scanned, %d subjects validated\n' \
  "${#files[@]}" "$total"
