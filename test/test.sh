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

# ---- Test: repeated calls for same session don't double-count ----
test_idempotent() {
  echo "test_idempotent"
  local d; d=$(new_dir); set_budget 100 "$d"
  local json='{"session_id":"sX","cost":{"total_cost_usd":10.00}}'
  run_gauge "$d" "$json" >/dev/null
  run_gauge "$d" "$json" >/dev/null
  local out; out=$(run_gauge "$d" "$json")   # 3rd call, still $10 total
  assert_contains "idempotent total stays \$10" '$10.00/$100' "$out"
  assert_contains "10%" '10%' "$out"
  rm -rf "$d"
}

# ---- Test: distinct sessions accumulate ----
test_multi_session() {
  echo "test_multi_session"
  local d; d=$(new_dir); set_budget 100 "$d"
  run_gauge "$d" '{"session_id":"a","cost":{"total_cost_usd":30.00}}' >/dev/null
  local out; out=$(run_gauge "$d" '{"session_id":"b","cost":{"total_cost_usd":20.00}}')
  assert_contains "30+20 = \$50 total" '$50.00/$100' "$out"
  assert_contains "50%" '50%' "$out"
  rm -rf "$d"
}

test_idempotent
test_multi_session

# ---- Test: BUDGET unset -> empty ----
test_no_budget() {
  echo "test_no_budget"
  local d; d=$(new_dir)   # no config written
  local out; out=$(run_gauge "$d" '{"session_id":"s","cost":{"total_cost_usd":5}}')
  assert_empty "no budget -> empty" "$out"
  rm -rf "$d"
}

# ---- Test: corrupt spend.json recovered ----
test_corrupt_spend() {
  echo "test_corrupt_spend"
  local d; d=$(new_dir); set_budget 100 "$d"
  printf 'not json{{' > "$d/spend.json"
  local out; out=$(run_gauge "$d" '{"session_id":"s","cost":{"total_cost_usd":5.00}}')
  assert_contains "recovers from corrupt spend" '$5.00/$100' "$out"
  rm -rf "$d"
}

# ---- Test: overflow >100% clamps bar, shows real % + red ----
test_overflow() {
  echo "test_overflow"
  local d; d=$(new_dir); set_budget 50 "$d"
  local out; out=$(run_gauge "$d" '{"session_id":"s","cost":{"total_cost_usd":54.00}}')
  assert_contains "shows 108%" '108%' "$out"
  assert_contains "red icon at overflow" '🔴' "$out"
  assert_contains "bar fully filled" '▓▓▓▓▓▓▓▓▓▓' "$out"
  rm -rf "$d"
}

# ---- Test: --segment has no trailing newline ----
test_segment_no_newline() {
  echo "test_segment_no_newline"
  local d; d=$(new_dir); set_budget 100 "$d"
  local out; out=$(run_gauge "$d" '{"session_id":"s","cost":{"total_cost_usd":5.00}}' --segment)
  # Last byte of raw --segment output must NOT be a newline (0a).
  local last; last=$(BUDGET_GAUGE_DIR="$d" printf '%s' '{"session_id":"s","cost":{"total_cost_usd":5.00}}' | BUDGET_GAUGE_DIR="$d" bash "$GAUGE" --segment | od -An -tx1 | tr -d ' \n' | tail -c2)
  if [ "$last" != "0a" ]; then PASS=$((PASS+1)); echo "  ok: segment has no trailing newline"; else FAIL=$((FAIL+1)); echo "  FAIL: segment ended with newline"; fi
  assert_contains "segment still shows gauge" '$5.00/$100' "$out"
  rm -rf "$d"
}

# ---- Test: warning icon at 75-89% ----
test_warn_icon() {
  echo "test_warn_icon"
  local d; d=$(new_dir); set_budget 100 "$d"
  local out; out=$(run_gauge "$d" '{"session_id":"s","cost":{"total_cost_usd":80.00}}')
  assert_contains "orange at 80%" '🟠' "$out"
  rm -rf "$d"
}

test_no_budget
test_corrupt_spend
test_overflow
test_segment_no_newline
test_warn_icon

# ---- Test: malformed stdin JSON -> empty, no crash ----
test_malformed_json() {
  echo "test_malformed_json"
  local d; d=$(new_dir); set_budget 100 "$d"
  local out; out=$(run_gauge "$d" 'not json at all {{{')
  assert_empty "malformed json -> empty" "$out"
  rm -rf "$d"
}

# ---- Test: model field absent + no cost -> hidden ----
test_no_model_no_cost() {
  echo "test_no_model_no_cost"
  local d; d=$(new_dir); set_budget 100 "$d"
  local out; out=$(run_gauge "$d" '{"session_id":"s","context_window":{"total_input_tokens":1000000}}')
  assert_empty "no model + no cost -> empty" "$out"
  rm -rf "$d"
}

test_malformed_json
test_no_model_no_cost

# ---- Test: reset clears accumulated spend ----
test_reset() {
  echo "test_reset"
  local d; d=$(new_dir); set_budget 100 "$d"
  run_gauge "$d" '{"session_id":"a","cost":{"total_cost_usd":40.00}}' >/dev/null
  BUDGET_GAUGE_DIR="$d" bash "$HERE/../budget-reset.sh" --yes >/dev/null
  local out; out=$(run_gauge "$d" '{"session_id":"b","cost":{"total_cost_usd":3.00}}')
  assert_contains "after reset only new \$3" '$3.00/$100' "$out"
  rm -rf "$d"
}
test_reset

# ---- Test: interactive 'y' confirm clears spend ----
test_reset_interactive_yes() {
  echo "test_reset_interactive_yes"
  local d; d=$(new_dir); set_budget 100 "$d"
  run_gauge "$d" '{"session_id":"a","cost":{"total_cost_usd":40.00}}' >/dev/null
  echo "y" | BUDGET_GAUGE_DIR="$d" bash "$HERE/../budget-reset.sh" >/dev/null
  local out; out=$(run_gauge "$d" '{"session_id":"b","cost":{"total_cost_usd":3.00}}')
  assert_contains "interactive y clears to \$3" '$3.00/$100' "$out"
  rm -rf "$d"
}

# ---- Test: interactive abort keeps spend ----
test_reset_interactive_abort() {
  echo "test_reset_interactive_abort"
  local d; d=$(new_dir); set_budget 100 "$d"
  run_gauge "$d" '{"session_id":"a","cost":{"total_cost_usd":40.00}}' >/dev/null
  echo "n" | BUDGET_GAUGE_DIR="$d" bash "$HERE/../budget-reset.sh" >/dev/null
  local out; out=$(run_gauge "$d" '{"session_id":"a","cost":{"total_cost_usd":40.00}}')
  assert_contains "abort keeps \$40" '$40.00/$100' "$out"
  rm -rf "$d"
}

test_reset_interactive_yes
test_reset_interactive_abort

# ---- gauge-lib unit tests ----
# Source the lib into the CURRENT shell (NOT a subshell) so assert_*/PASS/FAIL propagate.
test_gauge_render_basic() {
  echo "test_gauge_render_basic"
  . "$HERE/../gauge-lib.sh"
  assert_eq "render 23.4/100" '💰 $23.40/$100 ▓▓░░░░░░░░ 23%' "$(gauge_render 23.4 100)"
  assert_eq "render warn 80/100" '🟠 $80.00/$100 ▓▓▓▓▓▓▓▓░░ 80%' "$(gauge_render 80 100)"
  assert_eq "render overflow 54/50" '🔴 $54.00/$50 ▓▓▓▓▓▓▓▓▓▓ 108%' "$(gauge_render 54 50)"
}
test_gauge_render_no_newline() {
  echo "test_gauge_render_no_newline"
  . "$HERE/../gauge-lib.sh"
  local out; out=$(gauge_render 5 100)
  assert_contains "render produces output" '$5.00/$100' "$out"
  local last; last=$(printf '%s' "$out" | od -An -tx1 | tr -d ' \n' | tail -c2)
  if [ "$last" != "0a" ]; then PASS=$((PASS+1)); echo "  ok: gauge_render emits no trailing newline"; else FAIL=$((FAIL+1)); echo "  FAIL: gauge_render added a newline"; fi
}
test_gauge_total() {
  echo "test_gauge_total"
  . "$HERE/../gauge-lib.sh"
  local d; d=$(new_dir)
  printf '%s' '{"a":30,"b":20.5}' > "$d/spend.json"
  assert_eq "sum two entries" '50.5' "$(gauge_total "$d/spend.json")"
  assert_eq "missing file -> 0" '0' "$(gauge_total "$d/nope.json")"
  printf 'broken{{' > "$d/bad.json"
  assert_eq "corrupt -> 0" '0' "$(gauge_total "$d/bad.json")"
  rm -rf "$d"
}
test_gauge_render_basic
test_gauge_render_no_newline
test_gauge_total

BUDGETCMD="$HERE/../budget"
# ---- budget status ----
test_budget_status() {
  echo "test_budget_status"
  local d; d=$(new_dir); set_budget 100 "$d"
  printf '%s' '{"a":18.4,"b":5}' > "$d/spend.json"
  local out; out=$(BUDGET_GAUGE_DIR="$d" bash "$BUDGETCMD" status)
  assert_eq "status renders gauge" '💰 $23.40/$100 ▓▓░░░░░░░░ 23%' "$out"
  rm -rf "$d"
}
test_budget_status_default() {
  echo "test_budget_status_default"
  local d; d=$(new_dir); set_budget 100 "$d"
  printf '%s' '{"a":18.4,"b":5}' > "$d/spend.json"
  local out; out=$(BUDGET_GAUGE_DIR="$d" bash "$BUDGETCMD")
  assert_eq "no-arg = status" '💰 $23.40/$100 ▓▓░░░░░░░░ 23%' "$out"
  rm -rf "$d"
}
test_budget_status_no_budget() {
  echo "test_budget_status_no_budget"
  local d; d=$(new_dir)
  local out; out=$(BUDGET_GAUGE_DIR="$d" bash "$BUDGETCMD" status)
  assert_contains "guides when unset" 'No budget set' "$out"
  rm -rf "$d"
}
# ---- budget set ----
test_budget_set_writes_only_budget() {
  echo "test_budget_set_writes_only_budget"
  local d; d=$(new_dir)
  printf '%s\n' '# my config' 'BUDGET=100' 'CURRENCY_SYMBOL=$' > "$d/config"
  BUDGET_GAUGE_DIR="$d" bash "$BUDGETCMD" set 50 >/dev/null
  assert_contains "BUDGET updated" 'BUDGET=50' "$(cat "$d/config")"
  assert_contains "comment preserved" '# my config' "$(cat "$d/config")"
  assert_contains "other key preserved" 'CURRENCY_SYMBOL=$' "$(cat "$d/config")"
  assert_eq "single BUDGET line" '1' "$(grep -c '^BUDGET=' "$d/config")"
  rm -rf "$d"
}
test_budget_set_creates_config() {
  echo "test_budget_set_creates_config"
  local d; d=$(new_dir)
  BUDGET_GAUGE_DIR="$d" bash "$BUDGETCMD" set 75 >/dev/null
  assert_contains "config created with BUDGET" 'BUDGET=75' "$(cat "$d/config")"
  rm -rf "$d"
}
test_budget_set_appends_when_missing_line() {
  echo "test_budget_set_appends_when_missing_line"
  local d; d=$(new_dir)
  printf '%s\n' '# only a comment' 'BAR_WIDTH=12' > "$d/config"
  BUDGET_GAUGE_DIR="$d" bash "$BUDGETCMD" set 60 >/dev/null
  assert_contains "BUDGET appended" 'BUDGET=60' "$(cat "$d/config")"
  assert_contains "existing line kept" 'BAR_WIDTH=12' "$(cat "$d/config")"
  rm -rf "$d"
}
test_budget_set_rejects_bad() {
  echo "test_budget_set_rejects_bad"
  local d; d=$(new_dir); set_budget 100 "$d"
  if BUDGET_GAUGE_DIR="$d" bash "$BUDGETCMD" set abc >/dev/null 2>&1; then FAIL=$((FAIL+1)); echo "  FAIL: accepted non-number"; else PASS=$((PASS+1)); echo "  ok: rejects non-number"; fi
  if BUDGET_GAUGE_DIR="$d" bash "$BUDGETCMD" set 0 >/dev/null 2>&1; then FAIL=$((FAIL+1)); echo "  FAIL: accepted zero"; else PASS=$((PASS+1)); echo "  ok: rejects zero"; fi
  assert_contains "config unchanged" 'BUDGET=100' "$(cat "$d/config")"
  rm -rf "$d"
}
# ---- budget reset ----
test_budget_reset() {
  echo "test_budget_reset"
  local d; d=$(new_dir); set_budget 100 "$d"
  printf '%s' '{"a":40}' > "$d/spend.json"
  BUDGET_GAUGE_DIR="$d" bash "$BUDGETCMD" reset --yes >/dev/null
  assert_eq "reset clears to 0" '0' "$(. "$HERE/../gauge-lib.sh"; gauge_total "$d/spend.json")"
  rm -rf "$d"
}
test_budget_status
test_budget_status_default
test_budget_status_no_budget
test_budget_set_writes_only_budget
test_budget_set_creates_config
test_budget_set_appends_when_missing_line
test_budget_set_rejects_bad
test_budget_reset

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
