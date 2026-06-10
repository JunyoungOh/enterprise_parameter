# claude-budget-gauge

`claude-budget-gauge` is a per-developer, real-time CLI gauge that tracks cumulative API-equivalent spend against a self-set allotment (e.g. $100 or $50) and renders it as a bar in the Claude Code `statusLine`. It fills the gap left by official Claude dashboards, which are monthly and admin-only — and by reporting-only tools like `ccusage` that show cost history but do not support a user-defined budget with a manual reset cycle.

## Requirements

- **bash** (macOS or Linux)
- **jq** — `brew install jq` or `apt install jq`

## Install

> Replace `<your-org>` with the actual GitHub org/user once published.

```bash
git clone https://github.com/<your-org>/claude-budget-gauge.git
cd claude-budget-gauge
bash install.sh
```

`install.sh` creates:

| Path | Purpose |
|------|---------|
| `~/.claude/budget-gauge/config` | Your budget settings (edit `BUDGET` here) |
| `~/.claude/budget-gauge/spend.json` | Accumulated session costs (auto-managed) |

It also writes `statusLine` into `~/.claude/settings.json` so the gauge appears automatically in every Claude Code session.

**If you already have a `statusLine` configured**, `install.sh` will not overwrite it. It will instead print compose instructions so you can display the gauge alongside your existing statusline (see [Compose with an existing statusline](#compose-with-an-existing-statusline)).

## Configure

Edit `~/.claude/budget-gauge/config`:

```bash
# Your allotment in USD. The gauge fills to 100% at this amount.
BUDGET=100

# Optional overrides:
# CURRENCY_SYMBOL=$
# BAR_WIDTH=10
```

## Refill / Reset

When you want to start a new budget period, reset accumulated spend:

```bash
bash ~/path/to/claude-budget-gauge/budget-reset.sh        # prompts y/N
bash ~/path/to/claude-budget-gauge/budget-reset.sh --yes  # or -y, no prompt
```

Run it from wherever the repo is cloned (use the full path, or add the script to your PATH / a shell alias).

This clears `~/.claude/budget-gauge/spend.json`, resetting the gauge to $0.

## Compose with an existing statusline

`budget-gauge.sh` supports a `--segment` flag that emits the gauge without a trailing newline, suitable for inline composition:

```bash
# In your existing statusline script:
gauge=$(printf '%s' "$input" | /path/to/budget-gauge.sh --segment)
printf '%s │ %s\n' "$your_line" "$gauge"
```

Here `$input` is the stdin JSON your statusline script captures at the top with `input=$(cat)`.

In segment mode the script reads the same `statusLine` stdin JSON as the full mode — no extra plumbing needed.

## How cost is computed

Cost is tracked per session and accumulated across sessions. Each update is idempotent: re-processing the same `session_id` replaces (not adds to) that session's entry.

**Tier 1 — official value (preferred):** If the `statusLine` JSON contains `.cost.total_cost_usd`, that value is used directly. This reflects whatever models were actually used and any server-side pricing changes.

**Tier 2 — token fallback:** When `.cost.total_cost_usd` is absent, cost is estimated from token counts in `.context_window` using a built-in pricing table:

| Model | Input | Output | Cache write | Cache read |
|-------|------:|-------:|------------:|-----------:|
| opus  | $15   | $75    | $18.75      | $1.50      |
| sonnet | $3   | $15    | $3.75       | $0.30      |
| haiku | $1    | $5     | $1.25       | $0.10      |

Prices are per 1 million tokens. **Rates as of 2026-06 — fallback only; verify against current Anthropic pricing before relying on these figures.**

If neither tier produces a value (unknown model, no cost field), the gauge is hidden entirely rather than showing a misleading $0.

## Output format

```
💰 $23.40/$100 ▓▓░░░░░░░░ 23%
```

| Threshold | Icon | Meaning |
|-----------|------|---------|
| < 75%     | 💰   | Normal  |
| >= 75%    | 🟠   | Warning |
| >= 90% or overflow | 🔴 | Critical |

At overflow the bar is shown fully filled and the real percentage is displayed (e.g. `108%`):

```
🔴 $54.00/$50 ▓▓▓▓▓▓▓▓▓▓ 108%
```

## Privacy

All data is local. The script reads `statusLine` stdin, writes to `~/.claude/budget-gauge/spend.json`, and produces terminal output. No network requests. No telemetry.

## License

MIT — see [LICENSE](LICENSE).
