# Claudette

A two-line status bar for the Claude Code TUI showing context window usage, session cost, rate limits, and more — at a glance.

---

## What it shows

**Line 1 — Identity**
```
 Sonnet v2.1.90  │  my-project [auth-refactor]
```
- Model name + version
- Current directory
- Session name (if set with `--name` or `/rename`)
- Agent name (if using `--agent`) — prefixed with `▸`
- Active worktree (if using `--worktree`) — prefixed with `⌥`

**Line 2 — Metrics**
```
 ██████░░░░ 58%/200k  │  $0.1847  22m5s  │  +312/-97  │  ••••·····41% 5h  ••········18% 7d  ↺ 2h14m
```
- Context window progress bar (color-coded: green → yellow → orange → red)
- Session cost + elapsed time
- Lines added / removed
- Rate limit bars for the 5-hour and 7-day windows *(Pro/Max only)*
  - Cyan for the 5h window, purple for the 7h window
  - Both turn red above 80%
  - Countdown to reset (`↺ 2h14m`)

---

## Requirements

- [Claude Code](https://claude.ai/code) installed
- [`jq`](https://jqlang.github.io/jq/) — JSON parser used by the script
  ```bash
  # macOS
  brew install jq

  # Ubuntu / Debian
  sudo apt install jq
  ```

---

## Install

One-liner — downloads the script, makes it executable, and wires it into your Claude Code settings:

```bash
curl -fsSL https://raw.githubusercontent.com/lombare/Claudette/main/claudette.sh \
  -o ~/.claude/claudette.sh \
  && chmod +x ~/.claude/claudette.sh \
  && jq '. + {"statusLine": {"type": "command", "command": "~/.claude/claudette.sh"}}' \
     ~/.claude/settings.json > /tmp/settings.json \
  && mv /tmp/settings.json ~/.claude/settings.json \
  && echo "Done — restart Claude Code to apply."
```

> If `~/.claude/settings.json` doesn't exist yet, create it first:
> ```bash
> echo '{}' > ~/.claude/settings.json
> ```

### Manual install

1. Copy `claudette.sh` to `~/.claude/claudette.sh`
2. Make it executable:
   ```bash
   chmod +x ~/.claude/claudette.sh
   ```
3. Add to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/claudette.sh"
     }
   }
   ```
4. Restart Claude Code.

---

## Customization

All colors are defined as variables at the top of the script — easy to swap:

```bash
# Rate bar colors (default: cyan for 5h, purple for 7d)
RATE5_COLOR="$CYAN"
RATE7_COLOR="$PURPLE"

# Both bars turn red above this threshold (default: 80)
# Change the value in rate_color() if you want an earlier warning
```

Context bar thresholds (in the script):

| Usage | Color  |
|-------|--------|
| < 50% | Green  |
| 50–69% | Yellow |
| 70–89% | Orange |
| ≥ 90% | Red    |

---

## Troubleshooting

**Status bar not showing up**
- Check the script is executable: `chmod +x ~/.claude/claudette.sh`
- Test it manually: `echo '{"model":{"display_name":"Sonnet"},"version":"2.1.90","context_window":{"used_percentage":42,"context_window_size":200000},"cost":{"total_cost_usd":0.05,"total_duration_ms":120000},"workspace":{"current_dir":"/home/user/project"}}' | ~/.claude/claudette.sh`
- Make sure `disableAllHooks` is not set to `true` in your settings

**Rate limits not showing**
- This field is only available for Claude.ai Pro/Max subscribers
- It appears after the first API response in a session

**Reset time showing in minutes only**
- Make sure you're on the latest version of the script — earlier versions didn't convert minutes to `Xh Ym` format

---

## License

MIT
