#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Verify the ARM64 product; run its startup path natively on the available host.
set -euo pipefail
cd "${0:A:h}/.."
bundle="${1:-dist/Nodal.app}"
bundle="${bundle:A}"
python3 scripts/audit_publication.py --bundle "$bundle"
codesign --verify --deep --strict "$bundle"
mkdir -p build/module-cache
check_dir="$(mktemp -d "$PWD/build/check-bundle.XXXXXX")"
host_arch="$(uname -m)"
if [[ "$host_arch" == arm64 ]]; then
  executable="$bundle/Contents/MacOS/Nodal"
  detail='Arranque ejecutado con el binario ARM64 distribuible.'
elif [[ "$host_arch" == x86_64 ]]; then
  check_app="$check_dir/Nodal Check.app"
  ditto "$bundle" "$check_app"
  xcrun swiftc -swift-version 5 -target x86_64-apple-macosx13.0 -O -debug-prefix-map "$PWD"=. -file-prefix-map "$PWD"=. -module-cache-path build/module-cache -I Sources/CSQLite -framework AppKit -framework WebKit -framework UserNotifications Sources/*.swift -o "$check_app/Contents/MacOS/Nodal"
  codesign --force --deep --sign - "$check_app"
  codesign --verify --deep --strict "$check_app"
  executable="$check_app/Contents/MacOS/Nodal"
  detail='Arranque ejecutado con una copia temporal x86_64 del mismo código y recursos. El binario ARM64 se ha compilado y auditado; su ejecución no se prueba en Intel.'
else
  print -u2 "Arquitectura de ejecutor no admitida: $host_arch"
  exit 1
fi
NODAL_DATA="$check_dir/data" "$executable" --check
print -- "$detail"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  print -- "Ejecutor: $host_arch. $detail" >> "$GITHUB_STEP_SUMMARY"
fi
