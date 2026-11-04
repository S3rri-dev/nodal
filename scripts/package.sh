#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "${0:A:h}/.."
app='dist/Nodal.app'
[[ -d "$app" ]] || ./scripts/build.sh
python3 scripts/audit_publication.py --bundle "$app"
codesign --verify --deep --strict "$app"
version="$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")"
stage="$(mktemp -d "$PWD/build/package.XXXXXX")"
ditto "$app" "$stage/Nodal.app"
cp README.md LICENSE TRADEMARKS.md THIRD_PARTY_NOTICES.md "$stage/"
mkdir -p "$stage/Ejemplos"
cp examples/plan-demo.xml "$stage/Ejemplos/"
ln -s /Applications "$stage/Aplicaciones"
hdiutil create -volname Nodal -srcfolder "$stage" -format UDZO -ov "dist/Nodal-$version-arm64.dmg"
hdiutil verify "dist/Nodal-$version-arm64.dmg"
git archive --format=zip --prefix="Nodal-$version/" --output="dist/Nodal-$version-src.zip" HEAD
NODAL_VERSION="$version" python3 - <<'PY'
import os,hashlib,json,subprocess
from pathlib import Path
v=os.environ['NODAL_VERSION'];dist=Path('dist')
files=[f'Nodal-{v}-arm64.dmg',f'Nodal-{v}-src.zip']
manifest=dict(version=v,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
              architecture='arm64',deployment_target='13.0',signing='ad-hoc',notarized=False,
              artifacts={name:hashlib.sha256((dist/name).read_bytes()).hexdigest() for name in files})
name=f'Nodal-{v}-manifest.json';(dist/name).write_text(json.dumps(manifest,indent=2)+'\n');files.append(name)
(dist/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256((dist/p).read_bytes()).hexdigest()+'  '+p+'\n' for p in files))
print('Paquetes y SHA-256 generados para',v)
PY
