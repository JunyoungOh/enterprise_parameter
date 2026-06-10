#!/usr/bin/env bash
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
DIR="${BUDGET_GAUGE_DIR:-$HOME/.claude/budget-gauge}"
SETTINGS="$HOME/.claude/settings.json"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required. Install jq and re-run."; exit 1; }

mkdir -p "$DIR"
if [ -f "$DIR/config" ]; then
  echo "• Keeping existing config: $DIR/config"
else
  cp "$REPO/budget.conf.example" "$DIR/config"
  echo "• Created config: $DIR/config  (edit BUDGET there; default 100)"
fi
[ -f "$DIR/spend.json" ] || echo '{}' > "$DIR/spend.json"

CMD="bash $REPO/budget-gauge.sh"
if [ -f "$SETTINGS" ] && jq -e '.statusLine.command' "$SETTINGS" >/dev/null 2>&1; then
  echo
  echo "⚠ You already have a statusLine configured. Not overwriting it."
  echo "  To show the gauge alongside your existing statusline, append this in your"
  echo "  statusline script (it reads the same stdin):"
  echo
  echo "      gauge=\$(printf '%s' \"\$input\" | $REPO/budget-gauge.sh --segment)"
  echo "      printf '%s │ %s\\n' \"\$your_line\" \"\$gauge\""
  echo
else
  mkdir -p "$HOME/.claude"
  tmp=$(mktemp)
  if [ -f "$SETTINGS" ]; then base=$(cat "$SETTINGS"); else base='{}'; fi
  printf '%s' "$base" | jq --arg c "$CMD" '.statusLine = {type:"command", command:$c}' > "$tmp" && mv -f "$tmp" "$SETTINGS"
  echo "• Set statusLine.command in $SETTINGS"
fi
echo "Done. Open a new Claude Code session to see the gauge."
