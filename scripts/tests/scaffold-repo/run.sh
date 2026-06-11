#!/usr/bin/env bash
# Smoke tests for scripts/scaffold-repo.sh.
# Per the scaffold-procedure spec and the apply-phase decision (smoke level).
# Covers:
#   - happy path for each runtime (rust, python, typescript)
#   - unknown-context failure
# Not exhaustive — see the spec for the full requirements surface.

set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
codex_root=$(cd "$script_dir/../../.." && pwd)
scaffold="$codex_root/scripts/scaffold-repo.sh"

pass=0
fail=0

report_ok()  { printf '  \033[32mOK\033[0m   %s\n' "$1"; pass=$((pass + 1)); }
report_err() { printf '  \033[31mFAIL\033[0m %s — %s\n' "$1" "$2"; fail=$((fail + 1)); }

run_happy_path() {
  local context=$1
  local expected_runtime=$2
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN

  if ! out=$(bash "$scaffold" "$context" "$tmp/repo" 2>&1); then
    report_err "happy path $context" "scaffold-repo returned non-zero: $out"
    return
  fi

  # OWNERSHIP.yaml must exist and carry the expected runtime
  if [ ! -f "$tmp/repo/OWNERSHIP.yaml" ]; then
    report_err "happy path $context" "missing OWNERSHIP.yaml"
    return
  fi
  actual_runtime=$(yq -r .runtime "$tmp/repo/OWNERSHIP.yaml")
  if [ "$actual_runtime" != "$expected_runtime" ]; then
    report_err "happy path $context" "OWNERSHIP.runtime=$actual_runtime, expected $expected_runtime"
    return
  fi

  # Mandatory files
  for f in README.md AGENTS.md OWNERSHIP.yaml .github/workflows/ci.yml; do
    if [ ! -f "$tmp/repo/$f" ]; then
      report_err "happy path $context" "mandatory file missing: $f"
      return
    fi
  done

  # No leftover placeholders in OWNERSHIP.yaml
  if grep -q '\${' "$tmp/repo/OWNERSHIP.yaml"; then
    report_err "happy path $context" "unsubstituted placeholders in OWNERSHIP.yaml"
    return
  fi

  report_ok "happy path $context (runtime=$expected_runtime)"
}

run_unknown_context() {
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN

  if bash "$scaffold" no-such-context-9999 "$tmp/repo" >/dev/null 2>&1; then
    report_err "unknown context" "scaffold-repo unexpectedly succeeded"
    return
  fi
  if [ -d "$tmp/repo" ] && [ -n "$(ls -A "$tmp/repo" 2>/dev/null)" ]; then
    report_err "unknown context" "scaffold-repo wrote files for an unknown context"
    return
  fi
  report_ok "unknown context is rejected without writing"
}

printf 'scaffold-repo smoke tests\n'
run_happy_path lexicon rust
run_happy_path cortex python
run_happy_path app typescript
run_unknown_context

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
