// SPDX-License-Identifier: GPL-3.0-or-later
'use strict';
const gradeDecimal=value=>value==null?'—':value.toLocaleString('es-ES',{minimumFractionDigits:2,maximumFractionDigits:2});
const gradePercent=value=>value.toLocaleString('es-ES',{maximumFractionDigits:2})+' %';
function gradeConditions(subject){
 const text='Introduce las ponderaciones según la guía docente vigente de tu asignatura.';
 return disclosure('grades-conditions-'+subject.id,'Condiciones de evaluación','<p class="source-note">'+esc(text)+'</p><p class="source-note">La media no comprueba mínimos por bloque ni otras condiciones de evaluación.</p>');
}
function gradeComponentRow(component,index){
 const n=index+1;
 function input(key,label,decimal=false){
  return '<input name="'+key+index+'" aria-label="'+esc(label+' del componente '+n)+'" value="'+esc(component[key])+'"'+(decimal?' inputmode="decimal" placeholder="—"':'')+'>';
 }
 const menu='<details class="more-menu grade-component-menu"><summary aria-label="Opciones del componente '+n+'">⋯</summary><div class="more-options">'+button('removeGradeComponent','Eliminar componente','data-index="'+index+'"','grade-delete')+'</div></details>';
 return '<div class="grade-component-row" role="group" aria-label="Componente '+n+'" data-grade-component="'+index+'"><div>'+input('name','Nombre')+'</div><div>'+input('group','Bloque')+'</div><div>'+input('weight','Peso',true)+'</div><div>'+input('grade','Nota',true)+'</div><div>'+menu+'</div></div>';
}
function gradeDialog(draft=null,subjectID=selectedSubject){
 const subject=find(subjectID)||subjects()[0];if(!subject)throw Error('No hay una asignatura disponible.');
 const components=GradeModel.normalize(draft??subject.user?.gradeComponents??[]);
 const table='<div class="grade-components"><div class="grade-component-heading" aria-hidden="true"><span>Componente</span><span>Bloque</span><span>Peso %</span><span>Nota / 10</span><span></span></div>'+components.map(gradeComponentRow).join('')+'</div>';
 showDialog('Calculadora · '+subject.title,'Añade las pruebas y sus pesos. Deja vacías las notas que todavía no conoces.',
  '<form data-form="grades">'+(components.length?table:'<div class="grade-empty">No hay componentes. Añade el primero para empezar.</div>')+
  '<p class="grade-form-feedback" role="alert" tabindex="-1" hidden></p><p class="source-note grade-edit-hint">Los cambios se guardan al pulsar Guardar y calcular. Enter pasa al siguiente campo.</p>'+
  '<div class="dialog-footer">'+button('addGradeComponent','Añadir componente','','grade-add')+'<button type="submit" class="primary">Guardar y calcular</button></div></form>'+gradeConditions(subject),null,true);
 dialogState={kind:'grades',subjectID:subject.id,components,saving:false};
}
function collectGrades(form=document.querySelector('[data-form=grades]')){
 if(!form||dialogState?.kind!=='grades')throw Error('Vuelve a abrir la calculadora.');
 const values=Object.fromEntries(new FormData(form));
 return dialogState.components.map((_,i)=>({name:values['name'+i]??'',group:values['group'+i]??'',weight:values['weight'+i]??'',grade:values['grade'+i]??''}));
}
function gradeRing(result){
 const value=gradeDecimal(result.value),description=result.value==null?'Sin media calculable':'Media ponderada '+value+' sobre 10'+(result.provisional?', provisional':'');
 return '<div class="grade-ring" data-grade-band="'+result.band+'" data-grade-value="'+(result.value??'')+'" role="img" aria-label="'+esc(description)+'">'+
  '<svg viewBox="0 0 200 200" aria-hidden="true"><circle class="grade-track" cx="100" cy="100" r="82"/>'+
  (result.value==null?'':'<circle class="grade-arc" cx="100" cy="100" r="82" pathLength="100" transform="rotate(-90 100 100)" stroke-dasharray="'+result.progress+' 100" style="--grade-progress:'+result.progress+'"/>')+
  '</svg><div class="grade-ring-center" aria-hidden="true"><strong>'+value+'</strong><span>/ 10</span></div></div>';
}
function gradeResultDialog(subjectID,result){
 const subject=find(subjectID);if(!subject)throw Error('Asignatura no localizada.');
 const summary=result.value==null?'<p>Aún no hay notas con un peso positivo para calcular la media.</p>':
  '<p>Calculada sobre el <b>'+gradePercent(result.knownWeight)+'</b> que tiene nota y ponderación.</p>';
 const pending=result.provisional&&result.value!=null?'<p class="source-note">'+gradePercent(Math.max(0,100-result.knownWeight))+' sin nota o sin definir. La media es provisional.</p>':'';
 const unweighted=result.unweightedGrades?'<p class="notice">'+result.unweightedGrades+' nota(s) sin ponderación. Se conservan, pero no entran en la media.</p>':'';
 const rows=result.components.map((c,i)=>'<tr><td>'+esc(c.name||'Componente '+(i+1))+'</td><td>'+esc(c.group)+'</td><td>'+esc(c.weight||'—')+'</td><td>'+esc(c.grade||'—')+'</td></tr>').join('');
 const legend=[['red','0–4,99'],['yellow','5–5,99'],['green','6–8,99'],['gold','9–10']].map(([tone,text])=>'<span data-grade-band="'+tone+'"><i></i>'+text+'</span>').join('');
 showDialog('Resultado · '+subject.title,'',
  '<p class="grade-saved" role="status">'+icon('check')+'Componentes guardados</p><div class="grade-result-layout">'+gradeRing(result)+
  '<div class="grade-result-copy"><h3>'+(result.value==null?'Sin media todavía':'Media ponderada')+'</h3>'+summary+pending+
  '<dl class="grade-metrics"><div><dt>Aportación conocida a la nota final</dt><dd>'+gradeDecimal(result.contribution)+' / 10</dd></div><div><dt>Pesos definidos</dt><dd>'+gradePercent(result.totalWeight)+'</dd></div></dl></div></div>'+
  '<div class="grade-legend" aria-label="Colores de la media">'+legend+'</div>'+unweighted+
  disclosure('grades-saved-components-'+subjectID,'Componentes guardados · '+result.components.length,result.components.length?'<table class="table"><thead><tr><th>Componente</th><th>Bloque</th><th>Peso %</th><th>Nota / 10</th></tr></thead><tbody>'+rows+'</tbody></table>':'<p class="source-note">No hay componentes guardados.</p>')+
  gradeConditions(subject)+'<div class="dialog-footer">'+button('editGradeComponents','Editar componentes')+button('closeModal','Cerrar','','primary')+'</div>',null,true);
 dialogState={kind:'gradeResult',subjectID};
}
async function saveGradeForm(form,state){
 if(state?.kind!=='grades'||state.saving)return;
 const feedback=form.querySelector('.grade-form-feedback'),submit=form.querySelector('[type=submit]');
 let timer;
 try{
  feedback.hidden=true;
  const result=GradeModel.calculate(collectGrades(form));
  state.saving=true;form.setAttribute('aria-busy','true');form.setAttribute('inert','');submit.disabled=true;submit.textContent='Guardando…';
  await Promise.race([api('saveUser',{id:state.subjectID,user:{gradeComponents:result.components}}),
   new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('No se ha confirmado el guardado. Reabre la calculadora para comprobar los datos antes de repetirlo.')),15000)})]);
  const subject=find(state.subjectID);if(subject)subject.user={...subject.user,gradeComponents:structuredClone(result.components)};
  if(dialogState===state)gradeResultDialog(state.subjectID,result);else toast('Componentes guardados');
 }catch(error){
  if(dialogState===state){feedback.textContent=error.message;feedback.hidden=false;setTimeout(()=>{if(feedback.isConnected&&!feedback.hidden)feedback.focus()},0)}else toast(error.message);
 }finally{
  clearTimeout(timer);state.saving=false;form.removeAttribute('aria-busy');form.removeAttribute('inert');submit.disabled=false;submit.textContent='Guardar y calcular';
 }
}
actions.grades=()=>gradeDialog();
actions.addGradeComponent=()=>{
 if(dialogState?.kind!=='grades'||dialogState.saving)return;
 const id=dialogState.subjectID,components=collectGrades();
 if(components.length>=100){toast('La calculadora admite hasta 100 componentes.');return}
 components.push(GradeModel.blank());gradeDialog(components,id);
 setTimeout(()=>{const inputs=$('#modal').querySelectorAll('[name^=name]');inputs[inputs.length-1]?.focus()},0);
};
actions.removeGradeComponent=b=>{
 if(dialogState?.kind!=='grades'||dialogState.saving)return;
 const id=dialogState.subjectID,components=collectGrades(),index=Number(b.dataset.index);
 if(!Number.isInteger(index)||index<0||index>=components.length)throw Error('Componente no localizado.');
 components.splice(index,1);gradeDialog(components,id);
};
actions.editGradeComponents=()=>gradeDialog(null,dialogState.subjectID);
document.addEventListener('keydown',e=>{
 const form=e.target.closest?.('[data-form=grades]');
 if(e.key!=='Enter'||e.isComposing||!form||e.target.tagName!=='INPUT')return;
 e.preventDefault();const inputs=[...form.querySelectorAll('input')],next=inputs[inputs.indexOf(e.target)+1];next?.focus();
});
