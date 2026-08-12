#!/bin/sh
# Убирает statusline плагина из settings.json. Чужую строку не трогает.
# Вызывается из /mocha-powerline:disable.

root=${CLAUDE_PLUGIN_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
cfg=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
settings="$cfg/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "mocha-powerline: не найден jq"
  exit 0
fi

if [ ! -f "$settings" ]; then
  echo "mocha-powerline: $settings не существует — нечего отключать"
  exit 0
fi

current=$(jq -r '.statusLine.command // ""' "$settings" 2>/dev/null) || current=""

case "$current" in
  "")
    echo "mocha-powerline: statusLine и так не задан"
    exit 0
    ;;
  *mocha-powerline*) ;;
  *)
    echo "mocha-powerline: в settings.json чужая statusline ($current) — не трогаю"
    exit 0
    ;;
esac

tmp="$settings.mocha-powerline.tmp"
if jq 'del(.statusLine)' "$settings" >"$tmp" 2>/dev/null; then
  mv "$tmp" "$settings"
  echo "mocha-powerline: отключён, ключ statusLine удалён из $settings"
  echo "Чтобы хук не подключил его обратно на следующей сессии: claude plugin disable mocha-powerline"
else
  rm -f "$tmp"
  echo "mocha-powerline: не удалось прочитать $settings — ничего не менял"
fi

exit 0
