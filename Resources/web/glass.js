// SPDX-License-Identifier: GPL-3.0-or-later
'use strict';
(function(){
 const root=document.documentElement;
 const media={
  reduceTransparency:matchMedia('(prefers-reduced-transparency: reduce)'),
  reduceMotion:matchMedia('(prefers-reduced-motion: reduce)'),
  increaseContrast:matchMedia('(prefers-contrast: more)')
 };
 let native={},pending=null,frame=0;
 function synchronize(){
  root.dataset.reduceTransparency=String(!!native.reduceTransparency||media.reduceTransparency.matches);
  root.dataset.reduceMotion=String(!!native.reduceMotion||media.reduceMotion.matches);
  root.dataset.increaseContrast=String(!!native.increaseContrast||media.increaseContrast.matches);
 }
 window.accessibilityUpdate=flags=>{native=flags||{};synchronize()};
 Object.values(media).forEach(query=>query.addEventListener('change',synchronize));
 document.addEventListener('pointermove',event=>{
  if(root.dataset.reduceMotion==='true'||root.dataset.reduceTransparency==='true'||root.dataset.increaseContrast==='true')return;
  const surface=event.target.closest?.('.dialog,.more-options,.sidebar,.topbar');
  if(!surface)return;
  pending={surface,x:event.clientX,y:event.clientY};if(frame)return;
  frame=requestAnimationFrame(()=>{
   frame=0;const point=pending;pending=null;if(!point?.surface.isConnected)return;
   const rect=point.surface.getBoundingClientRect();
   point.surface.style.setProperty('--glass-x',Math.round(point.x-rect.left)+'px');
   point.surface.style.setProperty('--glass-y',Math.round(point.y-rect.top)+'px');
  });
 },{passive:true});
 const focus=()=>{root.dataset.windowActive=String(document.hasFocus())};
 window.addEventListener('focus',focus);window.addEventListener('blur',focus);
 synchronize();focus();
})();
