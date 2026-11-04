#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "${0:A:h}/.."
variant="${1:-release}"
[[ "$variant" == release || "$variant" == --dev ]] || { print 'Uso: scripts/build.sh [--dev]'; exit 2; }
python3 scripts/prepare_seed.py
app_name=Nodal
bundle_id=io.github.s3rri-dev.nodal
data_folder=Nodal
if [[ "$variant" == --dev ]]; then
 app_name='Nodal Dev';bundle_id=io.github.s3rri-dev.nodal.dev;data_folder='Nodal Dev'
fi
mkdir -p build/module-cache
app_dir="dist/$app_name.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
xcrun swiftc -swift-version 5 -target arm64-apple-macosx13.0 -O -debug-prefix-map "$PWD"=. -file-prefix-map "$PWD"=. -module-cache-path build/module-cache -I Sources/CSQLite -framework AppKit -framework WebKit -framework UserNotifications Sources/*.swift -o "$app_dir/Contents/MacOS/Nodal"
cp -R Resources/. "$app_dir/Contents/Resources/"
cp LICENSE "$app_dir/Contents/Resources/LICENSE.txt"
cp TRADEMARKS.md "$app_dir/Contents/Resources/TRADEMARKS.md"
cp THIRD_PARTY_NOTICES.md "$app_dir/Contents/Resources/THIRD_PARTY_NOTICES.md"
APP_OUTPUT="$app_dir" APP_LABEL="$app_name" APP_IDENTIFIER="$bundle_id" APP_DATA_FOLDER="$data_folder" python3 - <<'PY'
import plistlib,os
from pathlib import Path
p=Path(os.environ['APP_OUTPUT'])/'Contents/Info.plist'
d=dict(CFBundleExecutable='Nodal',CFBundleIdentifier=os.environ['APP_IDENTIFIER'],
       CFBundleName=os.environ['APP_LABEL'],CFBundleDisplayName=os.environ['APP_LABEL'],
       CFBundleDevelopmentRegion='es',CFBundleLocalizations=['es'],CFBundleIconFile='AppIcon',
       CFBundleVersion='8',CFBundleShortVersionString='1.6.0',CFBundlePackageType='APPL',
       LSMinimumSystemVersion='13.0',NSHighResolutionCapable=True,NSPrincipalClass='NSApplication',
       NodalDataFolder=os.environ['APP_DATA_FOLDER'],
       NSHumanReadableCopyright='Copyright © 2026 S3rri-dev y colaboradores. GPL-3.0-or-later; marca reservada.')
p.write_bytes(plistlib.dumps(d,sort_keys=False))
PY
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
print "Compilado: $app_dir · ARM64 · firma ad hoc"
