---
description: Отключить статусную строку Mocha Powerline
allowed-tools: Bash(sh:*)
---

Результат отключения:

!`sh "${CLAUDE_PLUGIN_ROOT}/hooks/unwire-statusline.sh"`

Перескажи пользователю результат одной-двумя фразами. Если строка отключена — напомни, что SessionStart-хук плагина подключит её обратно на следующей сессии, и чтобы этого не случилось, плагин надо выключить целиком: `claude plugin disable mocha-powerline`.
