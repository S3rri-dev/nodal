#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "${0:A:h}/.."
if [[ -n "${NODAL_NODE:-}" ]]; then
  ui_node="$NODAL_NODE"
elif command -v node >/dev/null 2>&1; then
  ui_node="$(command -v node)"
else
  ui_node="$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
fi
[[ -x "$ui_node" ]] || { print 'Indica un Node existente con NODAL_NODE. No se instalan dependencias.'; exit 1; }
"$ui_node" --check Resources/web/calendar-clock.js
"$ui_node" --check Resources/web/app.js
"$ui_node" --check Resources/web/glass.js
"$ui_node" --check Resources/web/grades-model.js
"$ui_node" --check Resources/web/grades.js
"$ui_node" --check Resources/web/planning.js
"$ui_node" tests/calendar-clock.cjs

"$ui_node" tests/grades.cjs
