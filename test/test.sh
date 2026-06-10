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

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
