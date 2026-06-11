#!/usr/bin/env bash
# Regenerate every scaffold baseline under
# openspec/specs/scaffold-procedure/baselines/rbrain-<context>.
# Run this whenever a template or a YAML source in openspec/specs/ is edited
# so that the scaffold-drift CI job stays green.
#
# Usage: bash scripts/refresh-baselines.sh

set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
codex_root=$(cd "$script_dir/.." && pwd)

baselines_dir="$codex_root/openspec/specs/scaffold-procedure/baselines"
catalog="$codex_root/openspec/specs/bounded-contexts/catalog.yaml"
alloc="$codex_root/openspec/specs/language-runtimes/runtime-allocation.yaml"

command -v yq >/dev/null 2>&1 || { echo "refresh-baselines: yq is required" >&2; exit 1; }

# Every context whose runtime is not 'none'
mapfile -t contexts < <(
  yq -r '.allocation | to_entries | .[] | select(.value != "none") | .key' "$alloc"
)

printf 'refresh-baselines: regenerating %d baselines\n' "${#contexts[@]}"

mkdir -p "$baselines_dir"

for ctx in "${contexts[@]}"; do
  target="$baselines_dir/rbrain-$ctx"
  printf '  → rbrain-%s\n' "$ctx"
  rm -rf "$target"
  bash "$codex_root/scripts/scaffold-repo.sh" "$ctx" "$target" >/dev/null
done

printf 'refresh-baselines: %d baselines refreshed under %s\n' \
  "${#contexts[@]}" "$baselines_dir"
