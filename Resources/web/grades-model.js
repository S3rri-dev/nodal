// SPDX-License-Identifier: GPL-3.0-or-later
'use strict';
(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory();else root.GradeModel=factory()})(typeof globalThis!=='undefined'?globalThis:this,function(){
 const blank=()=>({name:'',group:'Teoría',weight:'',grade:''});
 const normalize=items=>{
  if(!Array.isArray(items)||items.length>100)throw Error('La calculadora admite hasta 100 componentes.');
  return items.map(c=>{
   if(!c||typeof c!=='object'||Array.isArray(c))throw Error('Componente no válido.');
   return {name:String(c.name??''),group:String(c.group??''),weight:c.weight==null?'':String(c.weight),grade:c.grade==null?'':String(c.grade)};
  });
 };
 function numeric(value,label,maximum){
  const s=String(value??'').trim();if(s==='')return null;
  if(!/^[+-]?(?:\d+(?:[.,]\d*)?|[.,]\d+)$/.test(s))throw Error(label+': introduce un número válido.');
  const n=Number(s.replace(',','.'));
  if(!Number.isFinite(n)||n<0||n>maximum)throw Error(label+': valor entre 0 y '+maximum+'.');
  return n;
 }
 function band(value){return value==null?'neutral':value<5?'red':value<6?'yellow':value<9?'green':'gold'}
 function calculate(items){
  const components=normalize(items);let totalWeight=0,knownWeight=0,weightedSum=0,knownCount=0,unweightedGrades=0;
  components.forEach((c,i)=>{
   const w=numeric(c.weight,'Peso del componente '+(i+1),100),g=numeric(c.grade,'Nota del componente '+(i+1),10);
   if(w!=null)totalWeight+=w;
   if(g!=null&&w!=null&&w>0){knownWeight+=w;weightedSum+=w*g;knownCount++}
   if(g!=null&&w==null)unweightedGrades++;
  });
  if(totalWeight>100+1e-8)throw Error('Los pesos suman más del 100 %. Revisa los componentes.');
  const average=knownWeight>0?weightedSum/knownWeight:null;
  const value=average==null?null:Math.min(10,Math.max(0,Math.round((average+1e-12)*100)/100));
  return {components,totalWeight:Math.min(100,totalWeight),knownWeight:Math.min(100,knownWeight),knownCount,
   unweightedGrades,average,value,band:band(value),progress:value==null?0:value*10,
   contribution:knownWeight>0?weightedSum/100:null,provisional:knownWeight<100-1e-8};
 }
 return {blank,normalize,numeric,band,calculate};
});
