#!/bin/sh
# Прописывает statusline плагина в settings.json.
# Запускается на SessionStart (молча) и из /mocha-powerline:enable (с --verbose).
#
# Правила:
#   - уже подключено      → ничего не делает;
#   - statusLine не задан → подключает;
#   - там чужая строка    → НЕ трогает, только сообщает.
# Всегда завершается кодом 0, чтобы не ломать старт сессии.

verbose=""
[ "$1" = "--verbose" ] && verbose=1
say() { [ -n "$verbose" ] && echo "$1"; }

root=${CLAUDE_PLUGIN_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
cfg=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
settings="$cfg/settings.json"
desired="sh \"$root/statusline.sh\""

if ! command -v jq >/dev/null 2>&1; then
  say "mocha-powerline: не найден jq — statusline без него не работает (brew install jq)"
  exit 0
fi

[ -d "$cfg" ] || mkdir -p "$cfg"
[ -f "$settings" ] || printf '{}\n' >"$settings"

current=$(jq -r '.statusLine.command // ""' "$settings" 2>/dev/null) || current=""

if [ "$current" = "$desired" ]; then
  say "mocha-powerline: уже подключён"
  exit 0
fi

case "$current" in
  "" | *mocha-powerline*) ;;
  *)
    say "mocha-powerline: в settings.json уже своя statusline ($current) — оставил как есть."
    say "Чтобы заменить, удалите ключ statusLine и вызовите /mocha-powerline:enable."
    exit 0
    ;;
esac

tmp="$settings.mocha-powerline.tmp"
if jq --arg cmd "$desired" '.statusLine = {"type": "command", "command": $cmd}' "$settings" >"$tmp" 2>/dev/null; then
  mv "$tmp" "$settings"
  say "mocha-powerline: подключён → $desired"
else
  rm -f "$tmp"
  say "mocha-powerline: не удалось прочитать $settings (битый JSON?) — ничего не менял"
fi

exit 0
