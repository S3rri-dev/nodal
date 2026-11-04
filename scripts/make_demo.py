#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Generate an explicitly fictional plan and an in-memory preview fixture."""
import json,argparse,datetime as dt
from zoneinfo import ZoneInfo
from pathlib import Path
from xml.etree.ElementTree import Element,SubElement,ElementTree,indent
root=Path(__file__).resolve().parents[1]
args=argparse.ArgumentParser();args.add_argument('--date',default='2026-11-04');a=args.parse_args()
today=dt.date.fromisoformat(a.date);monday=today-dt.timedelta(days=today.weekday())
clock=dt.datetime.now(ZoneInfo('Europe/Madrid'))
entities=[]
def add(id,kind,user=None,**plan):
 e=dict(id=id,kind=kind,plan=plan)
 if user:e['user']=user
 entities.append(e)
subjects=[('MAT','Matemáticas','#D8B56A'),('PRO','Programación','#BD7088'),('DIS','Diseño de interfaces','#D39AAA')]
for sid,title,color in subjects:
 add(sid,'subject',title=title,color=color)
 add(sid+'-tema','topic',title={'MAT':'Integrales y aplicaciones','PRO':'Algoritmos y estructuras','DIS':'Prototipado y usabilidad'}[sid],subject=sid)
tasks=[('MAT-1','MAT','Cambio de variable'),('MAT-2','MAT','Integral por partes'),('PRO-1','PRO','Complejidad y recursión'),('PRO-2','PRO','Árboles de búsqueda'),('DIS-1','DIS','Jerarquía visual'),('DIS-2','DIS','Revisión del prototipo')]
for id,sid,title in tasks:
 add(id,'task',title=title,subject=sid,topic=sid+'-tema',objective='Resolver los ejercicios del bloque de demostración.',criterion='Explicar la solución y revisar los errores.',
     references='Guía de ejemplo · apartado 2',location='Biblioteca' if sid=='MAT' else 'Casa',dependencies=[],evaluation=sid+'-prueba')
for n,(sid,title,color) in enumerate(subjects):
 add(sid+'-prueba','event',title='Prueba de '+title.lower(),subject=sid,category='exam',date=str(today+dt.timedelta(days=7+n)))
for n in range(5):
 day=monday+dt.timedelta(days=n)
 sid=subjects[n%3][0]
 add('demo-clase-'+str(n),'event',title={'MAT':'Teoría y problemas','PRO':'Taller de algoritmos','DIS':'Diseño y accesibilidad'}[sid],subject=sid,category='class',
     start=str(day)+'T10:00:00',finish=str(day)+'T11:30:00',location='Aula de ejemplo')
 add('demo-estudio-'+str(n),'event',title=tasks[n%6][2],subject=tasks[n%6][1],task=tasks[n%6][0],category='study',
     start=str(day)+'T16:30:00',finish=str(day)+'T18:00:00',location='Biblioteca' if n%2==0 else 'Casa')
start=(clock-dt.timedelta(minutes=15)).replace(second=0,microsecond=0)
end=start+dt.timedelta(minutes=60)
if start.date()==today and end.date()==today:
 add('demo-actual','event',title='Cambio de variable',subject='MAT',task='MAT-1',category='study',
     start=start.strftime('%Y-%m-%dT%H:%M:%S'),finish=end.strftime('%Y-%m-%dT%H:%M:%S'),location='Biblioteca')
seed=dict(snapshot=str(today),context=dict(subjects=[dict(id=s,name=t) for s,t,c in subjects],user_confirmations=[],known_conflicts=[]),
          entities=entities,counts={'class':5,'exam':3,'study':6})
folder=root/'build';folder.mkdir(exist_ok=True)
(folder/'demo-seed.json').write_text(json.dumps(seed,ensure_ascii=False,indent=2)+'\n')
xml=Element('universidad',version='1',paquete='nodal-demo',revision='1',zona='Europe/Madrid',fechaRevision=str(today))
for entity in entities:
 row=SubElement(xml,'elemento',id=entity['id'],tipo=entity['kind'])
 for key,value in entity['plan'].items():
  node=SubElement(row,key)
  if isinstance(value,list):
   for item in value:SubElement(node,'ref').text=str(item)
  elif key in ('start','finish'):
   node.text=dt.datetime.fromisoformat(value).replace(tzinfo=ZoneInfo('Europe/Madrid')).isoformat()
  else:node.text=str(value)
indent(xml,space='  ')
(root/'examples').mkdir(exist_ok=True)
ElementTree(xml).write(root/'examples/plan-demo.xml',encoding='UTF-8',xml_declaration=True)
(root/'Resources/xml/ejemplo-plan.xml').write_bytes((root/'examples/plan-demo.xml').read_bytes())
# Only the screenshot fixture receives invented grade components.
for e in entities:
 if e['id']=='MAT':
  e['user']={'gradeComponents':[dict(name='Parcial de ejemplo',group='Teoría',weight='60',grade='9'),dict(name='Proyecto de ejemplo',group='Trabajo',weight='40',grade='10')]}
preview=dict(entities=[dict(id=e['id'],kind=e['kind'],**e['plan'],user=e.get('user',{})) for e in entities],
 events=[dict(id=e['id'],kind=e['kind'],**e['plan'],user={}) for e in entities if e['kind']=='event'],
 times=[],doubts=[dict(id='DEMO-Q1',subject='MAT',task='MAT-1',question='¿Cómo elegir el cambio de variable?',attempt='He probado una sustitución, pero no simplifica la integral.',
 reference='Guía de ejemplo · apartado 2',status='para tutoría',priority='media',recipient='profesor',date=clock.isoformat())],
 attempts=[],reviews=[],timer={},settings=dict(snapshot=str(today),materials='',theme='dark'),context=seed['context'],
 now=clock.isoformat(),imports=[],dataPath='Datos ficticios de demostración',backups=[])
preview['events'].sort(key=lambda e:e.get('start',e.get('date','')))
(folder/'demo-preview.json').write_text(json.dumps(preview,ensure_ascii=False,indent=2)+'\n')
print('Plan de ejemplo y fixture de capturas generados con datos ficticios.')
