#!/usr/bin/env bash
# gauge-lib.sh — pure rendering helpers for claude-budget-gauge.
# Sourced, not executed. No side effects, no policy (callers decide
# empty-output / messages / trailing newline).

# Refuse to run as a standalone script — this file only provides functions.
[ "${BASH_SOURCE[0]}" = "${0}" ] && { echo "gauge-lib.sh is meant to be sourced, not executed." >&2; exit 1; }

# gauge_render <total> <budget> [bar_width=10] [currency_symbol=$]
#   echoes "<icon> <sym><total.2f>/<sym><budget> <bar> <pct>%" with NO trailing newline.
#   returns 1 (no output) if pct can't be computed (e.g. awk missing).
gauge_render() {
  local total="$1" budget="$2" width="${3:-10}" sym="${4:-$}"
  local pct filled empty bar icon total_fmt i
  pct=$(awk -v t="$total" -v b="$budget" 'BEGIN{ printf "%.0f", (b>0 ? t/b*100 : 0) }')
  [ -z "$pct" ] && return 1
  filled=$(awk -v p="$pct" -v w="$width" 'BEGIN{ f=int(p/100*w+0.5); if(f>w)f=w; if(f<0)f=0; print f }')
  empty=$(( width - filled ))
  bar=""; for ((i=0;i<filled;i++)); do bar="${bar}▓"; done; for ((i=0;i<empty;i++)); do bar="${bar}░"; done
  if   [ "$pct" -ge 90 ]; then icon="🔴"
  elif [ "$pct" -ge 75 ]; then icon="🟠"
  else                         icon="💰"; fi
  total_fmt=$(awk -v t="$total" 'BEGIN{ printf "%.2f", t }')
  printf '%s' "${icon} ${sym}${total_fmt}/${sym}${budget} ${bar} ${pct}%"
}

# gauge_total <spend_json_path>
#   echoes the sum of all values in the spend JSON (missing/corrupt -> 0). No newline.
gauge_total() {
  local spend="$1" t
  t=$(jq -r 'to_entries | map(.value) | add // 0' "$spend" 2>/dev/null)
  [ -z "$t" ] && t=0
  printf '%s' "$t"
}
