#!/bin/sh
# Mocha Powerline — статусная строка для Claude Code.
# Палитра Catppuccin Mocha, powerline-разделители, сегменты:
# модель · каталог · git · python · контекст · лимиты подписки · время.
#
# Требуется: jq, Nerd Font в терминале, поддержка truecolor.
# Установка: положить в ~/.claude/statusline-command.sh и прописать в
# ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "sh \"$HOME/.claude/statusline-command.sh\"" }

# Percent thresholds at which a segment changes colour. LIMIT_DANGER also turns
# on the time until the window resets.
CTX_WARN=50
CTX_DANGER=70
LIMIT_WARN=80
LIMIT_DANGER=95

input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.cwd')
model=$(printf '%s' "$input" | jq -r '.model.display_name')
used_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')

dir_display=$(basename "$cwd" 2>/dev/null)
[ -z "$dir_display" ] && dir_display="$cwd"

# Git branch/status (skip optional locks: safe under concurrent git ops)
git_branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
git_segment=""
if [ -n "$git_branch" ]; then
  git_dirty=$(git --no-optional-locks -C "$cwd" status --porcelain 2>/dev/null)
  if [ -n "$git_dirty" ]; then
    git_segment="  ${git_branch} ✗"
  else
    git_segment="  ${git_branch}"
  fi
fi

# Python version, only shown when the cwd looks like a Python project
py_segment=""
if [ -f "$cwd/pyproject.toml" ] || [ -f "$cwd/setup.py" ] \
  || [ -f "$cwd/requirements.txt" ] || [ -f "$cwd/.python-version" ]; then
  py_version=$(python3 -V 2>/dev/null | awk '{print $2}')
  [ -n "$py_version" ] && py_segment="  ${py_version}"
fi

# Context window usage, shown when available
ctx_segment=""
if [ -n "$used_pct" ]; then
  ctx_segment=$(printf ' %.0f%%' "$used_pct")
fi

# Claude.ai subscription limits: 5h session window + 7d weekly window.
# Only present for subscribers, and only after the first API response.
five_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Compact "time until reset" (2h / 45m), only worth the pixels when a window is nearly spent
countdown() {
  [ -z "$1" ] && return
  left=$(( $1 - $(date +%s) ))
  [ "$left" -le 0 ] && return
  if [ "$left" -ge 3600 ]; then
    printf ' ↻%dh' $(( left / 3600 ))
  else
    printf ' ↻%dm' $(( left / 60 ))
  fi
}

# Usage level against the thresholds: ok | warn | danger. Non-numeric input is ok.
level() {
  int_part=${1%%.*}
  case "$int_part" in
    '' | *[!0-9]*) printf 'ok'; return ;;
  esac
  if [ "$int_part" -ge "$3" ]; then
    printf 'danger'
  elif [ "$int_part" -ge "$2" ]; then
    printf 'warn'
  else
    printf 'ok'
  fi
}

limit_segment=""
if [ -n "$five_pct" ]; then
  limit_segment=$(printf '5h %.0f%%' "$five_pct")
  [ "${five_pct%%.*}" -ge "$LIMIT_DANGER" ] 2>/dev/null && limit_segment="${limit_segment}$(countdown "$five_reset")"
fi
if [ -n "$week_pct" ]; then
  [ -n "$limit_segment" ] && limit_segment="${limit_segment} · "
  limit_segment=$(printf '%s7d %.0f%%' "$limit_segment" "$week_pct")
  [ "${week_pct%%.*}" -ge "$LIMIT_DANGER" ] 2>/dev/null && limit_segment="${limit_segment}$(countdown "$week_reset")"
fi

now=$(date '+%R')

# Catppuccin Mocha palette (truecolor)
crust='17;17;27'
red='243;138;168'
peach='250;179;135'
yellow='249;226;175'
green='166;227;161'
sapphire='116;199;236'
mauve='203;166;247'
lavender='180;190;254'

# Alarm colours deliberately sit outside the Catppuccin palette: it is pastel
# throughout, and an alarm in that range blends into its neighbours instead of
# warning. They need no Latte counterparts for the same reason.
warn_bg='255;196;0'
danger_bg='255;85;85'

# Segment background follows the thresholds. Context and limits share the alarm
# colours: when both are alarming, the merged block reads as one warning.
ctx_bg="$sapphire"
case "$(level "$used_pct" "$CTX_WARN" "$CTX_DANGER")" in
  warn) ctx_bg="$warn_bg" ;;
  danger) ctx_bg="$danger_bg" ;;
esac

limit_bg="$mauve"
five_level=$(level "$five_pct" "$LIMIT_WARN" "$LIMIT_DANGER")
week_level=$(level "$week_pct" "$LIMIT_WARN" "$LIMIT_DANGER")
case "$five_level$week_level" in
  *danger*) limit_bg="$danger_bg" ;;
  *warn*) limit_bg="$warn_bg" ;;
esac

fg() { printf '\033[38;2;%sm' "$1"; }
bg() { printf '\033[48;2;%sm' "$1"; }
reset() { printf '\033[0m'; }
# Powerline solid separator glyph (nerd font)
SEP=''

# Segment 1: model name (bg red)
printf '%s%s  %s ' "$(bg "$red")" "$(fg "$crust")" "$model"

# Segment 2: directory (bg peach)
printf '%s%s%s' "$(fg "$red")" "$(bg "$peach")" "$SEP"
printf '%s%s  %s ' "$(fg "$crust")" "$(bg "$peach")" "$dir_display"

# Segment 3: git branch/status (bg yellow), only when in a git repo
if [ -n "$git_segment" ]; then
  printf '%s%s%s' "$(fg "$peach")" "$(bg "$yellow")" "$SEP"
  printf '%s%s%s ' "$(fg "$crust")" "$(bg "$yellow")" "$git_segment"
  last_bg="$yellow"
else
  last_bg="$peach"
fi

# Segment 4: python version (bg green), only for python projects
if [ -n "$py_segment" ]; then
  printf '%s%s%s' "$(fg "$last_bg")" "$(bg "$green")" "$SEP"
  printf '%s%s%s ' "$(fg "$crust")" "$(bg "$green")" "$py_segment"
  last_bg="$green"
fi

# Segment 5: context window usage (bg by threshold, sapphire by default)
if [ -n "$ctx_segment" ]; then
  printf '%s%s%s' "$(fg "$last_bg")" "$(bg "$ctx_bg")" "$SEP"
  printf '%s%s 󰾆%s ' "$(fg "$crust")" "$(bg "$ctx_bg")" "$ctx_segment"
  last_bg="$ctx_bg"
fi

# Segment 6: subscription usage limits (bg by threshold, mauve by default)
if [ -n "$limit_segment" ]; then
  printf '%s%s%s' "$(fg "$last_bg")" "$(bg "$limit_bg")" "$SEP"
  printf '%s%s  %s ' "$(fg "$crust")" "$(bg "$limit_bg")" "$limit_segment"
  last_bg="$limit_bg"
fi

# Segment 7: time (bg lavender)
printf '%s%s%s' "$(fg "$last_bg")" "$(bg "$lavender")" "$SEP"
printf '%s%s  %s ' "$(fg "$crust")" "$(bg "$lavender")" "$now"
printf '%s%s' "$(fg "$lavender")" "$SEP"

reset
