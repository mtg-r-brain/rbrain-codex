#!/usr/bin/env bash
# Validate the forge-api response-shape schema and its lockstep with the
# spec and with forge's router.
# Data: openspec/specs/forge-api/schema.yaml; Spec: openspec/specs/forge-api/spec.md.
#
# Usage:
#   bash validate-response-shapes.sh              # self mode
#   bash validate-response-shapes.sh <repo-path>  # sibling mode (OWNERSHIP.yaml context)
#
# Self mode asserts:
#   - schema.yaml is well-formed per the schema grammar (field types, keys, refs)
#   - the schema's route set is exactly forge-api's closed eight
#   - the spec still declares exactly eight routes (route-count lockstep)
# Sibling mode, per OWNERSHIP.yaml context:
#   - forge: the Axum route set in src/lib.rs equals the schema's route set
#   - codex: falls through to self mode
#   Any other context fails loudly — no silent no-op on mis-wiring.
#
# Runtime mode (opt-in): with FORGE_URL set, additionally calls forge's
# stateless routes (GET /health, POST /decks/parse, POST /decks/analyze) and
# type-checks the response bodies against the schema. The user-scoped
# persistence routes need X-User-Id and a database, so they are out of this
# smoke's scope.
#
# Deliberately bash-3.2-compatible (no mapfile, no declare -A): unlike the
# CI-only validators this one is part of the documented local gate sequence
# on contributor macOS. Relies on yq only, matching the other validators.
#
# NOTE on types: yq v4's `type` operator returns YAML tags (!!map, !!seq,
# !!str, !!int, !!float, !!null), not jq's lowercase names. A JSON number
# arrives as !!int when integral and !!float when it carries a fraction, so
# the schema's `number` is checked as `!!int or !!float`.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
CODEX_ROOT=$(dirname "$SCRIPT_DIR")
SCHEMA_FILE="${SCHEMA_FILE:-$CODEX_ROOT/openspec/specs/forge-api/schema.yaml}"
SPEC_FILE="${SPEC_FILE:-$CODEX_ROOT/openspec/specs/forge-api/spec.md}"

die() {
  printf 'validate-response-shapes: %s\n' "$*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || die "yq is required; install via 'brew install yq'"
[ -r "$SCHEMA_FILE" ] || die "cannot read schema at $SCHEMA_FILE"
[ -r "$SPEC_FILE" ] || die "cannot read forge-api spec at $SPEC_FILE"

# The closed eight — the projection of forge-api's "No other public HTTP
# routes at v1" requirement. Kept here as the schema's expected set; the
# spec's own route-count clause is checked against it below.
EXPECTED_ROUTES=$(
  printf '%s\n' \
    'DELETE /decks/{id}' \
    'GET /decks' \
    'GET /decks/{id}' \
    'GET /health' \
    'POST /decks' \
    'POST /decks/analyze' \
    'POST /decks/parse' \
    'PUT /decks/{id}' | sort
)
EXPECTED_ROUTE_COUNT=$(printf '%s\n' "$EXPECTED_ROUTES" | wc -l | tr -d ' ')

# Valid field types and keys of the schema grammar (schema.yaml header).
VALID_TYPES='^(string|integer|number|boolean|object|array|null)$'
VALID_KEYS='^(type|nullable|required|enum|items|fields|additional)$'

schema_routes() {
  yq -r '.routes[] | "\(.method) \(.path)"' "$SCHEMA_FILE" | sort
}

# ---------------------------------------------------------------------------
# Self mode: schema shape + spec lockstep.
# ---------------------------------------------------------------------------

check_schema_shape() {
  # Structural: a components map and a non-empty routes list.
  yq -e '(.components | type) == "!!map" and (.routes | type) == "!!seq" and (.routes | length) > 0' \
    "$SCHEMA_FILE" >/dev/null \
    || die "schema lacks a components map or a non-empty routes list"

  # Every route declares method, path, and a non-empty responses map.
  yq -e '[.routes[] | select((has("method") and has("path") and (.responses | type) == "!!map" and ((.responses | length) > 0)) | not)] | length == 0' \
    "$SCHEMA_FILE" >/dev/null \
    || die "a route is missing method, path, or a non-empty responses map"

  # Field grammar: every type and every field-spec key is from the closed set.
  actual_types=$(yq '[.. | select(type == "!!map") | select(has("type")) | .type] | unique | .[]' "$SCHEMA_FILE" | sort)
  [ -n "$actual_types" ] || die "schema declares no field types"
  bad_types=$(printf '%s\n' "$actual_types" | grep -vE "$VALID_TYPES" || true)
  [ -z "$bad_types" ] || die "unknown field type(s): $(printf '%s ' $bad_types)"

  actual_keys=$(yq '[.. | select(type == "!!map") | select(has("type")) | keys[]] | unique | .[]' "$SCHEMA_FILE" | sort)
  bad_keys=$(printf '%s\n' "$actual_keys" | grep -vE "$VALID_KEYS" || true)
  [ -z "$bad_keys" ] || die "unknown field-spec key(s): $(echo $bad_keys)"

  # Component references resolve.
  refs=$(yq '[.. | select(type == "!!map") | .ref] | map(select(. != null)) | unique | .[]' "$SCHEMA_FILE" | sort)
  components=$(yq '.components | keys | .[]' "$SCHEMA_FILE" | sort)
  unresolved=$(comm -23 <(printf '%s\n' "$refs") <(printf '%s\n' "$components"))
  [ -z "$unresolved" ] || die "unresolved component reference(s): $(echo $unresolved)"

  # Route set is exactly the closed eight.
  actual_routes=$(schema_routes)
  if [ "$actual_routes" != "$EXPECTED_ROUTES" ]; then
    missing=$(comm -23 <(printf '%s\n' "$EXPECTED_ROUTES") <(printf '%s\n' "$actual_routes") | tr '\n' ' ')
    extra=$(comm -13 <(printf '%s\n' "$EXPECTED_ROUTES") <(printf '%s\n' "$actual_routes") | tr '\n' ' ')
    die "schema route set diverges from forge-api's closed eight; missing: ${missing:-none}; extra: ${extra:-none}"
  fi
}

check_spec_lockstep() {
  # The spec still declares the same closed eight as the schema.
  n=$(grep -cE 'exactly (eight|[0-9]+) HTTP routes' "$SPEC_FILE" || true)
  [ "$n" = "1" ] || die "expected exactly one route-closure clause in $SPEC_FILE, found $n"
  declared=$(grep -oE 'exactly [a-z]+ HTTP routes' "$SPEC_FILE" | head -1)
  [ "$declared" = "exactly eight HTTP routes" ] || die "route-closure clause in $SPEC_FILE says '$declared'; schema expects exactly eight"
}

# ---------------------------------------------------------------------------
# Sibling mode: forge's Axum route set equals the schema's.
# ---------------------------------------------------------------------------

check_forge_router() {
  repo=$1
  lib_rs="$repo/src/lib.rs"
  [ -r "$lib_rs" ] || die "cannot read $lib_rs"

  # Flatten the file so a `.route(" split over several lines (Axum allows it)
  # becomes a single segment, then cut one line per `.route(` call. Each
  # resulting line holds that route's path and its method-chain.
  segments=$(tr '\n' ' ' < "$lib_rs" | sed -E 's/\.route\(/\n.route(/g')

  actual=''
  while IFS= read -r line; do
    path=$(printf '%s\n' "$line" \
      | grep -oE '\.route\([[:space:]]*"[^"]*"' \
      | sed -E -e 's/\.route\([[:space:]]*"//' -e 's/"$//' -e 's/:([A-Za-z]+)/{\1}/g' \
      || true)
    [ -n "$path" ] || continue
    methods=$(printf '%s\n' "$line" \
      | grep -oE '\b(get|post|put|delete)\(' | tr -d '(' | tr '[:lower:]' '[:upper:]' | sort -u \
      || true)
    [ -n "$methods" ] || continue
    for method in $methods; do
      actual+="$method $path"$'\n'
    done
  done <<< "$segments"

  actual_sorted=$(printf '%s' "$actual" | sort)
  if [ "$actual_sorted" != "$EXPECTED_ROUTES" ]; then
    missing=$(comm -23 <(printf '%s\n' "$EXPECTED_ROUTES") <(printf '%s\n' "$actual_sorted") | tr '\n' ' ')
    extra=$(comm -13 <(printf '%s\n' "$EXPECTED_ROUTES") <(printf '%s\n' "$actual_sorted") | tr '\n' ' ')
    die "forge's Axum router diverges from the schema; missing: ${missing:-none}; extra: ${extra:-none}"
  fi
}

# ---------------------------------------------------------------------------
# Runtime mode: stateless-route smoke against a live forge.
# ---------------------------------------------------------------------------

check_health() {
  body=$(curl -fsS "$FORGE_URL/health") || die "GET /health failed"
  printf '%s' "$body" | yq -e \
    '(type == "!!map") and (.status | type == "!!str") and (.context | type == "!!str")' >/dev/null \
    || die "GET /health shape: got $body"
}

check_parse() {
  body=$(curl -fsS -X POST -H 'content-type: application/json' \
    -d '{"decklist":"4 Lightning Bolt\n2 Counterspell"}' "$FORGE_URL/decks/parse") \
    || die "POST /decks/parse failed"
  printf '%s' "$body" | yq -e '
    type == "!!map"
    and (.mainboard | type == "!!seq") and (.sideboard | type == "!!seq")
    and (.commander | type == "!!seq") and (.maybeboard | type == "!!seq")
    and (.errors | type == "!!seq")
    and (.total_mainboard | type == "!!int")
    and ([.mainboard[]] | all_c(.quantity | type == "!!int"))
    and ([.mainboard[]] | all_c(.name | type == "!!str"))
    and ([.errors[]] | all_c(.line | type == "!!int"))
    and ([.errors[]] | all_c(.content | type == "!!str"))
    and ([.errors[]] | all_c(.reason | type == "!!str"))' \
    >/dev/null || die "POST /decks/parse shape: got $body"
}

check_analyze() {
  body=$(curl -fsS -X POST -H 'content-type: application/json' \
    -d '{"decklist":"4 Lightning Bolt\n56 Mountain","card_facts":[{"name":"Lightning Bolt","mana_cost":"{R}","type_line":"Instant"},{"name":"Mountain","mana_cost":"","type_line":"Basic Land — Mountain"}]}' \
    "$FORGE_URL/decks/analyze") || die "POST /decks/analyze failed"
  printf '%s' "$body" | yq -e '
    type == "!!map"
    and (.mana_curve|type=="!!map") and (.average_cmc|type=="!!int" or .average_cmc|type=="!!float")
    and (.color_distribution|type=="!!map") and (.type_breakdown|type=="!!map")
    and (.total_mainboard|type=="!!int") and (.unresolved|type=="!!seq")
    and (.format == null or (.format|type=="!!str"))
    and (.format_violations|type=="!!seq")' \
    >/dev/null || die "POST /decks/analyze shape: got $body"
}

# ---------------------------------------------------------------------------

REPO_PATH="${1:-}"
context=codex
if [ -n "$REPO_PATH" ]; then
  [ -d "$REPO_PATH" ] || die "repo path '$REPO_PATH' is not a directory"
  [ -r "$REPO_PATH/OWNERSHIP.yaml" ] || die "missing $REPO_PATH/OWNERSHIP.yaml"
  context=$(yq -r '.context' "$REPO_PATH/OWNERSHIP.yaml")
fi

case "$context" in
  codex)
    check_schema_shape
    check_spec_lockstep
    ;;
  forge)
    check_schema_shape
    check_forge_router "$REPO_PATH"
    ;;
  *)
    die "context '$context' has no registered response-shape surface; register it here before wiring CI"
    ;;
esac

if [ -n "${FORGE_URL:-}" ]; then
  check_health
  check_parse
  check_analyze
  printf 'validate-response-shapes: OK — context=%s, %s routes, runtime smoke green\n' \
    "$context" "$EXPECTED_ROUTE_COUNT"
else
  printf 'validate-response-shapes: OK — context=%s, %s routes, spec lockstep green\n' \
    "$context" "$EXPECTED_ROUTE_COUNT"
fi
