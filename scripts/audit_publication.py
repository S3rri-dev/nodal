#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Fail publication when private artifacts or credentials enter the source/bundle."""
import argparse,json,re,plistlib,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--bundle',type=Path);args=parser.parse_args()
ignore={'build','dist','.git','.build','.swiftpm'}
patterns=[
 ('ruta personal absoluta',re.compile(rb'/Users/[A-Za-z0-9][A-Za-z0-9._-]+/')),
 ('ruta personal Linux',re.compile(rb'/home/[A-Za-z0-9][A-Za-z0-9._-]+/')),
 ('identificador de plan personal',re.compile(rb'@universidad-[a-z]')),
 ('token GitHub',re.compile(rb'gh[pousr]_[A-Za-z0-9]{30,}')),
 ('token GitHub granular',re.compile(rb'github_pat_[A-Za-z0-9_]{40,}')),
 ('clave privada',re.compile(rb'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----'))
]
errors=[];count=0
for p in root.rglob('*'):
 if any(part in ignore for part in p.relative_to(root).parts):continue
 if p.is_symlink():errors.append(str(p.relative_to(root))+': enlace no permitido');continue
 if not p.is_file():continue
 rel=str(p.relative_to(root))
 if p.suffix in ('.sqlite','.sqlite3','.p12','.p8','.key') or p.name.startswith('.env'):
  errors.append(rel+': archivo privado no permitido')
 data=p.read_bytes();count+=1
 for name,pattern in patterns:
  if pattern.search(data):errors.append(rel+': '+name)
seed=json.loads((root/'Resources/seed.json').read_text())
if seed.get('entities')!=[] or seed.get('context',{}).get('user_confirmations')!=[]:
 errors.append('Semilla del producto debe estar vacía')
if args.bundle:
 bundle=args.bundle.resolve()
 info=plistlib.loads((bundle/'Contents/Info.plist').read_bytes())
 if info.get('CFBundleIdentifier')!='io.github.s3rri-dev.nodal':errors.append('Identificador de bundle no oficial')
 if info.get('NodalDataFolder')!='Nodal':errors.append('Carpeta de datos no oficial')
 if 'MUTestDataDirectory' in info:errors.append('Ruta de pruebas en bundle')
 if json.loads((bundle/'Contents/Resources/seed.json').read_text())['entities']!=[]:errors.append('Datos en semilla del bundle')
 binary=(bundle/'Contents/MacOS/Nodal').read_bytes()
 for name,pattern in patterns:
  if pattern.search(binary):errors.append('Binario: '+name)
 arch=subprocess.check_output(['lipo','-archs',str(bundle/'Contents/MacOS/Nodal')],text=True).strip()
 if arch!='arm64':errors.append('Arquitectura distinta de ARM64: '+arch)
 if not (bundle/'Contents/Resources/LICENSE.txt').exists():errors.append('Licencia ausente del bundle')
if errors:
 for e in errors:print('ERROR:',e)
 raise SystemExit(1)
print(f'Auditoría pública correcta: {count} archivos, semilla vacía, sin rutas personales ni credenciales detectadas.')
print('La comprobación automática complementa la revisión de contenido; no es una auditoría de seguridad completa.')
