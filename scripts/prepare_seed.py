#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the empty public seed. Personal plans are never shipped."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
data=json.loads((root/'Resources/seed.json').read_text())
assert data['entities']==[], 'La distribución pública debe empezar vacía.'
assert data['context']['user_confirmations']==[]
assert data['context']['known_conflicts']==[]
print('Semilla pública válida: arranque limpio, sin planificación personal.')
