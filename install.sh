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

CMD="bash '$REPO/budget-gauge.sh'"
if [ -f "$SETTINGS" ] && jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
  echo
  echo "⚠ You already have a statusLine configured. Not overwriting it."
  echo "  To show the gauge alongside your existing statusline, append this in your"
  echo "  statusline script (it reads the same stdin):"
  echo
  echo "      gauge=\$(printf '%s' \"\$input\" | '$REPO/budget-gauge.sh' --segment)"
  echo "      printf '%s │ %s\\n' \"\$your_line\" \"\$gauge\""
  echo
else
  mkdir -p "$HOME/.claude"
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  if [ -f "$SETTINGS" ]; then base=$(cat "$SETTINGS"); else base='{}'; fi
  if printf '%s' "$base" | jq --arg c "$CMD" '.statusLine = {type:"command", command:$c}' > "$tmp" && mv -f "$tmp" "$SETTINGS"; then
    echo "• Set statusLine.command in $SETTINGS"
  else
    rm -f "$tmp"
    echo "ERROR: Failed to write $SETTINGS — check it is valid JSON and writable." >&2
    exit 1
  fi
fi
# --- /budget slash command (natural-language control inside Claude Code) ---
CMDDIR="$HOME/.claude/commands"
CMDFILE="$CMDDIR/budget.md"
mkdir -p "$CMDDIR"
if [ -f "$CMDFILE" ]; then
  echo "• Keeping existing /budget command: $CMDFILE"
else
  cat > "$CMDFILE" <<EOF
---
description: View or change your Claude Code budget gauge (set/reset/status)
allowed-tools: Bash($REPO/budget:*)
---
The user wants to manage their budget gauge. Their request: \$ARGUMENTS

Interpret the request and run exactly ONE of these via Bash, then report concisely:
- \`$REPO/budget set <amount>\` — change the budget (extract the number)
- \`$REPO/budget reset --yes\` — reset/refill the gauge to \$0
- \`$REPO/budget status\` — show current spend (DEFAULT if the request is empty or unclear)

Do NOT edit files directly; always go through the budget command.
EOF
  echo "• Installed /budget slash command: $CMDFILE"
fi

# --- optional: put 'budget' on PATH for direct shell use ---
case ":$PATH:" in
  *":$HOME/.local/bin:"*)
    if [ -e "$HOME/.local/bin/budget" ]; then
      echo "• ~/.local/bin/budget already exists — not touching it. Use: $REPO/budget"
    else
      ln -s "$REPO/budget" "$HOME/.local/bin/budget" && echo "• Linked 'budget' into ~/.local/bin (try: budget status)"
    fi
    ;;
  *)
    echo "• To run 'budget' directly, add an alias:  alias budget='$REPO/budget'"
    ;;
esac

echo "Done. Open a new Claude Code session to see the gauge."
