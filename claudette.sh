#!/bin/bash
input=$(cat)

# ── Extract fields ────────────────────────────────────────────────
MODEL=$(echo "$input"    | jq -r '.model.display_name // "Claude"')
VERSION=$(echo "$input"  | jq -r '.version // ""')
DIR=$(echo "$input"      | jq -r '.workspace.current_dir // ""')
SESSION=$(echo "$input"  | jq -r '.session_name // ""')
AGENT=$(echo "$input"    | jq -r '.agent.name // ""')

CTX_PCT=$(echo "$input"  | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

COST=$(echo "$input"     | jq -r '.cost.total_cost_usd // 0')
DUR_MS=$(echo "$input"   | jq -r '.cost.total_duration_ms // 0')
LINES_ADD=$(echo "$input"| jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input"| jq -r '.cost.total_lines_removed // 0')

RATE_5H=$(echo "$input"  | jq -r '.rate_limits.five_hour.used_percentage // empty')
RATE_7D=$(echo "$input"  | jq -r '.rate_limits.seven_day.used_percentage // empty')
RESET_5H=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

WORKTREE=$(echo "$input" | jq -r '.worktree.name // ""')

# ── ANSI colors ───────────────────────────────────────────────────
RESET='\033[0m'; BOLD='\033[1m'
GRAY='\033[90m'; CYAN='\033[96m'; GREEN='\033[92m'
YELLOW='\033[93m'; ORANGE='\033[38;5;208m'; RED='\033[91m'
BLUE='\033[94m'; MAGENTA='\033[95m'; PURPLE='\033[38;5;141m'

SEP="${GRAY}  │  ${RESET}"

# ── Context bar (10 chars) ────────────────────────────────────────
if   [ "$CTX_PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$CTX_PCT" -ge 70 ]; then BAR_COLOR="$ORANGE"
elif [ "$CTX_PCT" -ge 50 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

BAR_W=10; FILLED=$((CTX_PCT * BAR_W / 100)); EMPTY=$((BAR_W - FILLED))
printf -v F "%${FILLED}s"; printf -v E "%${EMPTY}s"
CTX_BAR="${F// /█}${E// /░}"
[ "$CTX_SIZE" -ge 900000 ] && CTX_LABEL="1M" || CTX_LABEL="200k"

# ── Mini rate bar (8 chars) ───────────────────────────────────────
mini_bar() {
  local pct=$1 color=$2 w=10 f label ll label_start
  f=$((pct * w / 100)); [ "$f" -gt "$w" ] && f=$w
  label="${pct}%"; ll=${#label}
  label_start=$(( (w - ll) / 2 ))
  local result="" i=0 char
  while [ "$i" -lt "$w" ]; do
    if [ "$i" -eq "$label_start" ]; then
      # emit each label char with its own fill-based color
      for (( c=0; c<ll; c++ )); do
        char="${label:$c:1}"
        if [ $(( i + c )) -lt "$f" ]; then
          result="${result}${color}${BOLD}${char}${RESET}"
        else
          result="${result}${GRAY}${BOLD}${char}${RESET}"
        fi
      done
      i=$(( i + ll ))
    else
      if [ "$i" -lt "$f" ]; then
        result="${result}${color}•${RESET}"
      else
        result="${result}${GRAY}·${RESET}"
      fi
      i=$(( i + 1 ))
    fi
  done
  echo "$result"
}

RATE5_COLOR="$CYAN"
RATE7_COLOR="$PURPLE"

rate_color() {
  local p=$1 base=$2
  [ "$p" -ge 80 ] && echo "$RED" || echo "$base"
}

# ── Duration ──────────────────────────────────────────────────────
DUR_SEC=$((DUR_MS / 1000))
DUR_MINS=$((DUR_SEC / 60)); DUR_SECS=$((DUR_SEC % 60))
COST_FMT=$(printf '$%.4f' "$COST")

# ── Line 1: identity ──────────────────────────────────────────────
L1="${BOLD}${PURPLE}${MODEL}${RESET}${GRAY} v${VERSION}${RESET}"
L1="${L1}${SEP}${CYAN}${DIR##*/}${RESET}"
[ -n "$SESSION" ]  && L1="${L1} ${GRAY}[${SESSION}]${RESET}"
[ -n "$AGENT" ]    && L1="${L1}${SEP}${MAGENTA}▸ ${AGENT}${RESET}"
[ -n "$WORKTREE" ] && L1="${L1}${SEP}${BLUE}⌥ ${WORKTREE}${RESET}"

# ── Line 2: metrics ───────────────────────────────────────────────
L2="${BAR_COLOR}${CTX_BAR}${RESET} ${BOLD}${BAR_COLOR}${CTX_PCT}%${RESET}${GRAY}/${CTX_LABEL}${RESET}"
L2="${L2}${SEP}${YELLOW}${COST_FMT}${RESET}  ${GRAY}${DUR_MINS}m${DUR_SECS}s${RESET}"

if [ "$((LINES_ADD + LINES_DEL))" -gt 0 ]; then
  L2="${L2}${SEP}${GREEN}+${LINES_ADD}${RESET}${GRAY}/${RESET}${RED}-${LINES_DEL}${RESET}"
fi

if [ -n "$RATE_5H" ]; then
  R5=$(printf '%.0f' "$RATE_5H"); R7=$(printf '%.0f' "$RATE_7D")
  RC5=$(rate_color "$R5" "$RATE5_COLOR"); RC7=$(rate_color "$R7" "$RATE7_COLOR")
  B5=$(mini_bar "$R5" "$RC5"); B7=$(mini_bar "$R7" "$RC7")
  if [ -n "$RESET_5H" ]; then
    NOW=$(date +%s); DIFF=$((RESET_5H - NOW))
    if [ "$DIFF" -gt 0 ]; then
      RM=$((DIFF / 60)); RS=$((DIFF % 60))
      [ "$RM" -ge 60 ] && RESETS=" ${GRAY}↺ $((RM/60))h$((RM%60))m${RESET}" || RESETS=" ${GRAY}↺ ${RM}m${RS}s${RESET}"
    else
      RESETS=" ${GRAY}↺ soon${RESET}"
    fi
  fi
  L2="${L2}${SEP}${B5} ${GRAY}5h${RESET}  ${B7} ${GRAY}7d${RESET}${RESETS}"
fi

# ── Output ────────────────────────────────────────────────────────
echo -e " ${L1}"
echo -e " ${L2}"