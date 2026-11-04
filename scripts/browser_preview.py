#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prepare a browser-only fixture; does not open or read a user database."""
import json,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[1];folder=root/'build/browser'
shutil.copytree(root/'Resources/web',folder,dirs_exist_ok=True)
p=folder/'preview.js';p.write_text('window.PREVIEW='+ (root/'build/demo-preview.json').read_text()+';')
bridge="""window.webkit={messageHandlers:{native:{postMessage(m){queueMicrotask(()=>{try{
 let result;
 if(m.action==='snapshot')result=structuredClone(window.PREVIEW);
 else if(m.action==='theme'){window.PREVIEW.settings.theme=m.params.value;result=true}
 else if(m.action==='saveUser'){let e=window.PREVIEW.entities.find(e=>e.id===m.params.id);if(!e)throw Error('Elemento de ejemplo ausente');e.user={...e.user,...structuredClone(m.params.user)};result=true}
 else throw Error('Esta vista de ejemplo solo permite revisar la interfaz.');
 window.nativeReply({id:m.id,ok:true,result});
}catch(e){window.nativeReply({id:m.id,ok:false,error:e.message})}})}}}};
"""
(folder/'fixture-bridge.js').write_text(bridge)
p=folder/'index.html';p.write_text(p.read_text().replace('<script src="calendar-clock.js">','<script src="preview.js"></script><script src="fixture-bridge.js"></script><script src="calendar-clock.js">'))
print('Vista sintética en build/browser; sin persistencia ni datos personales.')
