'use strict';
const assert=require('node:assert/strict'),G=require('../Resources/web/grades-model.js');let count=0;
function check(label,fn){fn();count++;console.log('✓ '+label)}
const c=(grade,weight=100)=>({name:'Ejemplo',group:'Teoría',grade,weight});
for(const [value,tone] of [[0,'red'],[4.99,'red'],[5,'yellow'],[5.99,'yellow'],[6,'green'],[8.99,'green'],[9,'gold'],[10,'gold']]){
 check('color y relleno para '+value,()=>{const r=G.calculate([c(value)]);assert.equal(r.band,tone);assert.equal(r.progress,value*10);assert.equal(r.value,value)});
}
check('media ponderada, no media aritmética',()=>{const r=G.calculate([c(6,30),c(8,70)]);assert.equal(r.value,7.4);assert.equal(r.contribution,7.4);assert.equal(r.provisional,false)});
check('notas ausentes no se convierten en cero',()=>{const r=G.calculate([c(8,50),c('',50)]);assert.equal(r.value,8);assert.equal(r.contribution,4);assert.equal(r.knownWeight,50);assert.equal(r.provisional,true)});
check('ponderación sin definir no entra en la media',()=>{const r=G.calculate([c(8,'')]);assert.equal(r.value,null);assert.equal(r.unweightedGrades,1);assert.equal(r.band,'neutral')});
check('peso cero no crea media',()=>assert.equal(G.calculate([c(9,0)]).value,null));
check('cero es una nota conocida',()=>{const r=G.calculate([c(0)]);assert.equal(r.value,0);assert.equal(r.contribution,0);assert.equal(r.knownCount,1)});
check('lista sin componentes no inventa nota',()=>{const r=G.calculate([]);assert.equal(r.value,null);assert.equal(r.contribution,null);assert.equal(r.progress,0)});
check('decimales españoles y espacios',()=>assert.equal(G.calculate([c(' 6,75 ','100,0')]).value,6.75));
check('redondeo y color coinciden en el límite de cinco',()=>{const r=G.calculate([c(4.995)]);assert.equal(r.value,5);assert.equal(r.band,'yellow')});
check('redondeo y color coinciden en el límite de nueve',()=>{const r=G.calculate([c(8.995)]);assert.equal(r.value,9);assert.equal(r.band,'gold')});
for(const [label,items] of [['nota negativa',[c(-1)]],['nota mayor que diez',[c(10.01)]],['peso negativo',[c(5,-1)]],['peso mayor que cien',[c(5,101)]],['pesos acumulados mayores que cien',[c(5,60),c(5,50)]],['NaN',[c('NaN')]],['infinito',[c(Infinity)]],['texto no numérico',[c('7foo')]],['decimal ambiguo',[c('1,2.3')]],['booleano',[c(true)]],['lista inválida',{}],['componente inválido',[null]],['más de cien componentes',Array.from({length:101},()=>c('',0))]]){
 check('rechaza '+label,()=>assert.throws(()=>G.calculate(items)));
}
check('no modifica los componentes recibidos',()=>{const input=[c(8,50),c('',50)],before=JSON.stringify(input);G.calculate(input);assert.equal(JSON.stringify(input),before)});
check('acepta pesos fraccionarios sin error de precisión',()=>assert.equal(G.calculate([c(7,33.33),c(7,33.33),c(7,33.34)]).value,7));
console.log(count+' comprobaciones de cálculo de notas superadas.');
