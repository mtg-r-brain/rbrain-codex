#!/usr/bin/env bash
# Validate that every <context>-api capability declares a route-closure clause.
# Spec: openspec/specs/repository-conventions/spec.md
#       ("<context>-api capabilities include a route-closure clause").
#
# Asserts: for every openspec/specs/<name>-api/spec.md, at least one
# requirement body matches the canonical closure pattern:
#     `SHALL expose exactly <quantified> **public** HTTP routes`
# OR the equivalent older wording (`SHALL expose exactly <quantified> HTTP
# routes` with no `**public**` marker — accepted for backward compatibility
# with lexicon-api's original phrasing).
#
# Exits 0 on success, non-zero with a message naming the offending capability.

set -euo pipefail

SPECS_DIR="${SPECS_DIR:-openspec/specs}"

die() {
  printf 'validate-api-closure: %s\n' "$*" >&2
  exit 1
}

[ -d "$SPECS_DIR" ] || die "cannot read $SPECS_DIR"

mapfile -t api_specs < <(
  find "$SPECS_DIR" -mindepth 2 -maxdepth 2 -name 'spec.md' -path "*-api/spec.md" | sort
)

if [ "${#api_specs[@]}" -eq 0 ]; then
  printf 'validate-api-closure: OK — no <context>-api capabilities to check\n'
  exit 0
fi

failures=0
for spec in "${api_specs[@]}"; do
  capability="$(basename "$(dirname "$spec")")"
  if grep -qE 'SHALL expose exactly (one|two|three|four|five|six|seven|eight|nine|ten) (\*\*)?public(\*\*)? HTTP routes' "$spec" \
     || grep -qE 'SHALL expose exactly (one|two|three|four|five|six|seven|eight|nine|ten) HTTP routes' "$spec"; then
    printf 'validate-api-closure: OK — %s declares its closure clause\n' "$capability"
  else
    printf 'validate-api-closure: FAIL — %s is missing a route-closure clause\n' "$capability" >&2
    printf '  Expected a requirement body matching:\n' >&2
    printf '    "SHALL expose exactly <N> **public** HTTP routes at v1 ..."\n' >&2
    printf '  See repository-conventions "<context>-api capabilities include a route-closure clause".\n' >&2
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  die "$failures capability/capabilities missing a closure clause"
fi

printf 'validate-api-closure: OK — %d <context>-api capabilit(y/ies) checked\n' "${#api_specs[@]}"
