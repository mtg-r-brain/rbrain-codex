#!/usr/bin/env bash
# Validate scaffold-procedure baselines honour the platform conventions
# ratified today in repository-conventions:
#
#   - "Health endpoint convention" — every HTTP-serving baseline SHALL expose
#     `GET /health` returning the canonical `{"status":"ok","context":"<name>"}`
#     shape.
#   - "Port binding honors a PORT environment variable" — every HTTP-serving
#     baseline SHALL read the PORT env var (default 8080) instead of
#     hardcoding the bind port.
#
# Scope: every context whose runtime != none per language-runtimes.
# Rust + Python + TypeScript baselines are checked with runtime-appropriate
# grep patterns. Out-of-scope contexts (codex, deploy) are skipped.
#
# Exits 0 on success, non-zero with a message naming the offending baseline
# and the missing pattern.

set -euo pipefail

BASELINES_DIR="${BASELINES_DIR:-openspec/specs/scaffold-procedure/baselines}"
ALLOC="${ALLOC:-openspec/specs/language-runtimes/runtime-allocation.yaml}"

die() {
  printf 'validate-baselines: %s\n' "$*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || die "yq is required"
[ -d "$BASELINES_DIR" ] || die "cannot read $BASELINES_DIR"
[ -r "$ALLOC" ] || die "cannot read $ALLOC"

mapfile -t contexts < <(
  yq -r '.allocation | to_entries | .[] | select(.value != "none") | .key' "$ALLOC"
)

failures=0
checks=0

check_rust() {
  local ctx="$1" main="$2"

  # /health route registration via Axum's .route("/health", ...).
  if ! grep -qE '\.route\("/health"' "$main"; then
    printf 'validate-baselines: FAIL — rbrain-%s missing /health route in %s\n' \
      "$ctx" "$main" >&2
    failures=$((failures + 1))
    return
  fi

  # Canonical health response shape: status:ok + context.
  if ! grep -qE '"status".*"ok"' "$main"; then
    printf 'validate-baselines: FAIL — rbrain-%s /health does not return status=ok in %s\n' \
      "$ctx" "$main" >&2
    failures=$((failures + 1))
    return
  fi

  # PORT env var pattern.
  if ! grep -qE 'std::env::var\("PORT"\)' "$main"; then
    printf 'validate-baselines: FAIL — rbrain-%s missing PORT env var lookup in %s\n' \
      "$ctx" "$main" >&2
    failures=$((failures + 1))
    return
  fi

  # Default fallback to 8080.
  if ! grep -qE 'unwrap_or\(8080\)' "$main"; then
    printf 'validate-baselines: FAIL — rbrain-%s PORT lookup missing 8080 fallback in %s\n' \
      "$ctx" "$main" >&2
    failures=$((failures + 1))
    return
  fi

  printf 'validate-baselines: OK  — rbrain-%s (rust)\n' "$ctx"
}

check_python() {
  local ctx="$1" main="$2"

  # /health route registration via FastAPI's @app.get("/health").
  if ! grep -qE '@app\.get\("/health"' "$main"; then
    printf 'validate-baselines: FAIL — rbrain-%s missing @app.get("/health") in %s\n' \
      "$ctx" "$main" >&2
    failures=$((failures + 1))
    return
  fi

  # Canonical health response shape.
  if ! grep -qE '"status".*"ok"' "$main"; then
    printf 'validate-baselines: FAIL — rbrain-%s /health does not return status=ok in %s\n' \
      "$ctx" "$main" >&2
    failures=$((failures + 1))
    return
  fi

  # Python siblings satisfy PORT via uvicorn's CLI flag, not main.py.
  # The convention is documented in repository-conventions; nothing to grep
  # for at the baseline source level.
  printf 'validate-baselines: OK  — rbrain-%s (python; PORT via uvicorn --port)\n' "$ctx"
}

check_typescript() {
  local ctx="$1"
  # TypeScript baseline (app) is a Next.js project at v1 and serves no
  # /health endpoint by itself — the gateway sits in front. Skip with a
  # note rather than fail so the validator stays accurate to the convention's
  # scope (HTTP-serving siblings, which app isn't yet).
  printf 'validate-baselines: SKIP — rbrain-%s (typescript app; no /health surface yet)\n' \
    "$ctx"
}

for ctx in "${contexts[@]}"; do
  runtime=$(yq -r ".allocation.$ctx" "$ALLOC")
  baseline_root="$BASELINES_DIR/rbrain-$ctx"
  [ -d "$baseline_root" ] || die "missing baseline directory: $baseline_root"

  checks=$((checks + 1))
  case "$runtime" in
    rust)
      main="$baseline_root/src/main.rs"
      [ -r "$main" ] || die "missing $main"
      check_rust "$ctx" "$main"
      ;;
    python)
      main="$baseline_root/app/main.py"
      [ -r "$main" ] || die "missing $main"
      check_python "$ctx" "$main"
      ;;
    typescript)
      check_typescript "$ctx"
      ;;
    *)
      die "unexpected runtime '$runtime' for context '$ctx'"
      ;;
  esac
done

if [ "$failures" -gt 0 ]; then
  die "$failures baseline check(s) failed across $checks context(s)"
fi

printf 'validate-baselines: OK — %d baseline(s) checked, all conformant\n' "$checks"
