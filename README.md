# claude-budget-gauge

> 🇰🇷 한국어 안내가 먼저 나옵니다 · 🇺🇸 English documentation follows below ([jump to English](#english)).

## 한국어 안내

`claude-budget-gauge`는 개발자 본인이 **Claude Code CLI 하단바(statusLine)에서, 지금까지 쓴 비용을 API 단가로 환산했을 때 내 배정액의 몇 %인지**를 실시간 게이지로 보는 가벼운 도구입니다. 사내에서 1회당 **$100 / $50**씩 배정받아 쓰는 사람을 위해 만들었습니다.

공식 Claude 대시보드는 월 단위·관리자 전용이고, `ccusage` 같은 도구는 비용을 "보고"만 할 뿐 *내가 정한 예산 대비 게이지*와 *수동 리셋*이 없습니다. 이 도구가 그 빈틈을 채웁니다.

### ⚡ 가장 쉬운 설치 — Claude Code에게 맡기기

설치법을 몰라도 됩니다. **Claude Code 세션에 이 저장소 링크를 붙여넣고** 이렇게 말하세요:

> 이 저장소 설치해줘: https://github.com/JunyoungOh/enterprise_parameter
> 그리고 내 예산을 100달러로 맞춰줘.

그러면 Claude가 아래 **[Claude용 설치 절차](#claude용-설치-절차-에이전트가-그대로-따라-실행)**를 순서대로 실행합니다. (`jq`가 없으면 설치 명령까지 안내합니다.) 끝나면 새 Claude Code 세션을 열기만 하면 하단바에 게이지가 나타납니다.

#### Claude용 설치 절차 (에이전트가 그대로 따라 실행)

> 이 저장소를 건네받은 Claude는 **추측하지 말고 아래 단계를 순서대로** 실행하세요. 모든 명령은 결정적입니다.

1. **`jq` 확인** — `command -v jq`. 없으면 macOS는 `brew install jq`, Linux는 `sudo apt install jq`(또는 배포판 패키지 매니저)로 설치 안내/실행.
2. **클론** — `git clone https://github.com/JunyoungOh/enterprise_parameter.git`
3. **이동** — `cd enterprise_parameter`
4. **설치** — `bash install.sh` (config·spend.json 생성, `/budget` 슬래시 명령 등록, statusLine 연결 — 기존 statusLine은 덮어쓰지 않음)
5. **예산 설정** — 사용자가 금액을 말했으면 `bash budget set <금액>`, 말하지 않았으면 기본값 100 유지.
6. **마무리 안내** — 사용자에게 "새 Claude Code 세션을 열면 하단바에 게이지가 보입니다"라고 알리고, 이후 `/budget` 으로 예산 변경·리셋이 가능함을 안내.

### 수동 설치

```bash
git clone https://github.com/JunyoungOh/enterprise_parameter.git
cd enterprise_parameter
bash install.sh
```

설치 시 생성되는 것: `~/.claude/budget-gauge/config`(예산 설정), `~/.claude/budget-gauge/spend.json`(누적 비용, 자동 관리), `~/.claude/commands/budget.md`(`/budget` 명령). 그리고 `~/.claude/settings.json`에 statusLine을 연결합니다. **이미 statusLine을 쓰고 있으면 덮어쓰지 않고** 합치는 방법을 출력합니다.

### 예산 설정 / 변경

- **설정 파일**: `~/.claude/budget-gauge/config` 의 `BUDGET=100` ($50 배정이면 50)
- **터미널**: `budget set 50`
- **Claude Code 안에서**: `/budget set 50` 또는 자연어로 "예산 50으로 바꿔줘"

### 명령어

| 명령 | 동작 |
|------|------|
| `budget` 또는 `budget status` | 현재 소진 게이지를 터미널에 표시 |
| `budget set <금액>` | 예산(USD) 설정 |
| `budget reset [--yes\|-y]` | 누적 소진액을 $0으로(배정액 충전); `--yes`/`-y` 없으면 확인 |
| `/budget …` | Claude Code 안에서 자연어로 — 예: `/budget 예산 반으로 줄여줘`, `/budget 리셋`, `/budget`(상태) |

> `budget`은 `<repo>/budget`으로 실행하거나, `~/.local/bin`이 PATH에 있으면 그냥 `budget`으로 실행합니다(install.sh가 가능하면 심링크를 만들어 줍니다).

### 하단바 표시

```
💰 $23.40/$100 ▓▓░░░░░░░░ 23%
```

아이콘: `<75% 💰` · `≥75% 🟠` · `≥90%·초과 🔴`. 초과 시 막대는 꽉 차고 실제 퍼센트(예: `108%`)를 보여줍니다.

### 비용 계산 방식

세션별로 추적해 누적합니다(같은 세션을 다시 처리하면 합산이 아니라 **덮어쓰기 = 멱등**이라 중복 집계되지 않음). 1순위로 Claude Code가 제공하는 실제 비용값(`.cost.total_cost_usd`)을 사용하고, 없으면 사용 모델별 토큰 단가표로 환산합니다. 둘 다 불가하면 잘못된 $0 대신 게이지를 숨깁니다.

### 프라이버시

모두 로컬에서 동작합니다 — 네트워크 호출도, 텔레메트리도 없습니다. 누적 소진액은 `~/.claude/budget-gauge/spend.json`에만 저장됩니다(git 추적 제외).

자세한 영어 문서는 아래에 이어집니다 ↓

---

<a id="english"></a>

`claude-budget-gauge` is a per-developer, real-time CLI gauge that tracks cumulative API-equivalent spend against a self-set allotment (e.g. $100 or $50) and renders it as a bar in the Claude Code `statusLine`. It fills the gap left by official Claude dashboards, which are monthly and admin-only — and by reporting-only tools like `ccusage` that show cost history but do not support a user-defined budget with a manual reset cycle.

## Quick setup with Claude Code

Don't know how to install it? Paste this repo link into a Claude Code session and ask it to set things up:

> Install this repo: https://github.com/JunyoungOh/enterprise_parameter — and set my budget to 100 dollars.

Claude will follow the deterministic steps below: check for `jq`, `git clone`, `cd enterprise_parameter`, `bash install.sh`, then `bash budget set <amount>`. Open a new Claude Code session afterward and the gauge appears in your statusline.

## Requirements

- **bash** (macOS or Linux)
- **jq** — `brew install jq` or `apt install jq`

## Install

```bash
git clone https://github.com/JunyoungOh/enterprise_parameter.git
cd enterprise_parameter
bash install.sh
```

`install.sh` creates:

| Path | Purpose |
|------|---------|
| `~/.claude/budget-gauge/config` | Your budget settings (edit `BUDGET` here) |
| `~/.claude/budget-gauge/spend.json` | Accumulated session costs (auto-managed) |
| `~/.claude/commands/budget.md` | The `/budget` slash command (created if absent) |

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

You can also change the budget at any time from the terminal:

```bash
<repo>/budget set 50
```

Or, inside a Claude Code session, use the `/budget` slash command (see [Natural language inside Claude Code](#natural-language-inside-claude-code)):

```
/budget set 50
```

## Commands

`budget` can be run as `<repo>/budget`, or as `budget` directly if `~/.local/bin` is on your PATH (install.sh sets up the symlink automatically when `~/.local/bin` is on PATH; otherwise it prints an alias suggestion).

| Command | Effect |
|---------|--------|
| `budget` or `budget status` | Show the current spend gauge in the terminal |
| `budget set <amount>` | Set your budget in USD (e.g. `budget set 100`) |
| `budget reset [--yes\|-y]` | Reset accumulated spend to $0; prompts for confirmation unless `--yes` / `-y` is given |
| `budget help` | Print usage |

## Refill / Reset

When you want to start a new budget period, reset accumulated spend:

```bash
<repo>/budget reset        # prompts y/N
<repo>/budget reset --yes  # or -y, no prompt
```

This clears `~/.claude/budget-gauge/spend.json`, resetting the gauge to $0.

> **Note:** `budget-reset.sh` is a deprecated shim; use `budget reset` instead.

## Natural language inside Claude Code

`install.sh` registers a `/budget` slash command in `~/.claude/commands/budget.md`. After installing, you can type natural-language requests directly in any Claude Code session:

```
/budget                          # show current gauge (default)
/budget set 50                   # set budget to $50
/budget 예산 반으로 줄여줘        # Claude extracts the number and calls budget set
/budget reset                    # reset accumulated spend
/budget status                   # explicit status
```

Claude interprets the request and runs exactly one of `budget status`, `budget set <amount>`, or `budget reset --yes` — no file editing, no guessing.

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
