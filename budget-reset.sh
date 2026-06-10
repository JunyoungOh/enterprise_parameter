#!/usr/bin/env bash
# Reset (refill) the budget gauge: clear accumulated spend.
DIR="${BUDGET_GAUGE_DIR:-$HOME/.claude/budget-gauge}"
SPEND="$DIR/spend.json"

if [ "${1:-}" != "--yes" ] && [ "${1:-}" != "-y" ]; then
  printf 'Reset budget gauge to $0? This clears %s [y/N] ' "$SPEND"
  read -r ans
  case "$ans" in y|Y|yes|YES) ;; *) echo "Aborted."; exit 0 ;; esac
fi
mkdir -p "$DIR"
echo '{}' > "$SPEND"
echo "Budget gauge reset. Spend is now \$0."
