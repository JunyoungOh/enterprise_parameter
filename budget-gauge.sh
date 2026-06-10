#!/usr/bin/env bash
# claude-budget-gauge — Claude Code statusLine budget gauge.
# Reads statusLine stdin JSON, tracks cumulative API-equivalent spend vs a
# user budget, renders a gauge. Never breaks the host statusline: every
# failure mode prints nothing and exits 0.

MODE="full"
[ "${1:-}" = "--segment" ] && MODE="segment"

DIR="${BUDGET_GAUGE_DIR:-$HOME/.claude/budget-gauge}"
CONFIG="$DIR/config"
SPEND="$DIR/spend.json"

emit() { # honor --segment (no trailing newline) vs full (newline)
  if [ "$MODE" = "segment" ]; then printf '%s' "$1"; else printf '%s\n' "$1"; fi
}

# jq is required; without it, degrade silently.
command -v jq >/dev/null 2>&1 || { echo "budget-gauge: jq not found" >&2; exit 0; }

input=$(cat)

# --- config ---
BUDGET=""; CURRENCY_SYMBOL='$'; BAR_WIDTH=10
# shellcheck disable=SC1090
[ -f "$CONFIG" ] && . "$CONFIG"
case "${BUDGET:-}" in ''|*[!0-9.]*) exit 0 ;; esac   # unset/non-numeric -> silent

session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
key="${session_id:-unknown}"

# --- this session's cost: tier 1 = CC official value ---
this_cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)

# (tier-2 fallback added in Task 4)
[ -z "$this_cost" ] && exit 0

# --- idempotent spend update: overwrite this session's entry, then sum ---
mkdir -p "$DIR"
[ -f "$SPEND" ] && jq -e . "$SPEND" >/dev/null 2>&1 || echo '{}' > "$SPEND"
tmp=$(mktemp "$DIR/.spend.XXXXXX")
if jq --arg k "$key" --argjson v "$this_cost" '.[$k] = $v' "$SPEND" > "$tmp" 2>/dev/null; then
  mv -f "$tmp" "$SPEND"
else
  rm -f "$tmp"
fi
total=$(jq -r 'to_entries | map(.value) | add // 0' "$SPEND" 2>/dev/null)
[ -z "$total" ] && total=0

# --- render ---
pct=$(awk -v t="$total" -v b="$BUDGET" 'BEGIN{ printf "%.0f", (b>0 ? t/b*100 : 0) }')
filled=$(awk -v p="$pct" -v w="$BAR_WIDTH" 'BEGIN{ f=int(p/100*w+0.5); if(f>w)f=w; if(f<0)f=0; print f }')
empty=$(( BAR_WIDTH - filled ))
bar=""; for ((i=0;i<filled;i++)); do bar="${bar}▓"; done; for ((i=0;i<empty;i++)); do bar="${bar}░"; done

if   [ "$pct" -ge 90 ]; then icon="🔴"
elif [ "$pct" -ge 75 ]; then icon="🟠"
else                         icon="💰"; fi

total_fmt=$(awk -v t="$total" 'BEGIN{ printf "%.2f", t }')
emit "${icon} ${CURRENCY_SYMBOL}${total_fmt}/${CURRENCY_SYMBOL}${BUDGET} ${bar} ${pct}%"
