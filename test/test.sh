#!/usr/bin/env bash
# Pure-bash test harness for budget-gauge.sh — no Claude Code required.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GAUGE="$HERE/../budget-gauge.sh"
PASS=0; FAIL=0

# Each test gets a clean data dir.
new_dir() { mktemp -d "${TMPDIR:-/tmp}/bg.XXXXXX"; }
set_budget() { printf 'BUDGET=%s\n' "$1" > "$2/config"; }

run_gauge() { # $1=dir  $2=stdin-json  [$3=flag]
  BUDGET_GAUGE_DIR="$1" printf '%s' "$2" | BUDGET_GAUGE_DIR="$1" bash "$GAUGE" ${3:-}
}

assert_eq() { # $1=label $2=expected $3=actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  ok: $1";
  else FAIL=$((FAIL+1)); echo "  FAIL: $1"; echo "    expected: [$2]"; echo "    actual:   [$3]"; fi
}
assert_contains() { # $1=label $2=needle $3=haystack
  if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); echo "  ok: $1";
  else FAIL=$((FAIL+1)); echo "  FAIL: $1"; echo "    needle:   [$2]"; echo "    haystack: [$3]"; fi
}
assert_empty() { # $1=label $2=actual
  if [ -z "$2" ]; then PASS=$((PASS+1)); echo "  ok: $1";
  else FAIL=$((FAIL+1)); echo "  FAIL: $1 (expected empty, got [$2])"; fi
}

# ---- Test: tier-1 uses .cost.total_cost_usd ----
test_tier1_cost() {
  echo "test_tier1_cost"
  local d; d=$(new_dir); set_budget 100 "$d"
  local json='{"session_id":"s1","model":{"id":"claude-opus-4-8"},"cost":{"total_cost_usd":23.40}}'
  local out; out=$(run_gauge "$d" "$json")
  assert_contains "shows total/budget" '$23.40/$100' "$out"
  assert_contains "shows 23%" '23%' "$out"
  rm -rf "$d"
}

test_tier1_cost

# ---- Test: tier-2 fallback for opus when .cost absent ----
test_tier2_opus() {
  echo "test_tier2_opus"
  local d; d=$(new_dir); set_budget 100 "$d"
  # 1,000,000 input tokens @ $15/1M = $15.00 exactly
  local json='{"session_id":"s2","model":{"id":"claude-opus-4-8"},"context_window":{"total_input_tokens":1000000,"total_output_tokens":0,"current_usage":{"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'
  local out; out=$(run_gauge "$d" "$json")
  assert_contains "opus 1M in = \$15.00" '$15.00/$100' "$out"
  assert_contains "15%" '15%' "$out"
  rm -rf "$d"
}

# ---- Test: unknown model + no cost -> hidden (empty) ----
test_unknown_model_hidden() {
  echo "test_unknown_model_hidden"
  local d; d=$(new_dir); set_budget 100 "$d"
  local json='{"session_id":"s3","model":{"id":"some-other-model"},"context_window":{"total_input_tokens":1000000}}'
  local out; out=$(run_gauge "$d" "$json")
  assert_empty "unknown model hides segment" "$out"
  rm -rf "$d"
}

test_tier2_opus
test_unknown_model_hidden

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
