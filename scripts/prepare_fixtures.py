#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent synthetic historical fixtures for deterministic regression tests."""
import json,shutil
from datetime import date,timedelta
from pathlib import Path
root=Path(__file__).resolve().parents[1]
dest=root/'build/test-resources';dest.mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'Resources/xml',dest/'xml',dirs_exist_ok=True)
entities=[]
def add(id,kind,user=None,**plan):
    e=dict(id=id,kind=kind,plan=plan)
    if user is not None:e['user']=user
    entities.append(e)
names=[('SS','Matemáticas'),('SED','Diseño digital'),('AC','Computación'),('PA','Algoritmos'),('PV','Interfaces')]
for sid,title in names:
    add(sid,'subject',title=title,color='#7A223C')
    add(sid+'-plan','topic',title='Ejercicios de ejemplo',subject=sid)
add('reserva','topic',title='Reserva',subject='')
for n in range(61):
    id='AC01' if n==0 else 'AC02' if n==1 else 'FIXTURE-TASK-'+str(n)
    sid='AC' if n<2 else names[n%5][0]
    add(id,'task',title='Ejercicio sintético '+str(n+1),subject=sid,topic=sid+'-plan',
        objective='Resolver un ejercicio de ejemplo.',criterion='Comprobar la solución.',
        references='Material de ejemplo',dependencies=[],location='Biblioteca',
        **({'evaluation':'ac-pe1@nodal.test'} if id=='AC01' else {}))
add('sed-teo-lun@nodal.test','series',title='SED · Clase de demostración',subject='SED',category='class',
    uid='sed-teo-lun@nodal.test',start='2026-10-05T10:00:00',finish='2026-10-05T12:00:00',
    rrule='FREQ=WEEKLY;COUNT=10;BYDAY=MO',exdates=['2026-10-12T10:00:00','2026-11-02T10:00:00'])
add('fixture-thursday@nodal.test','series',title='SED · Taller sintético',subject='SED',category='class',
    uid='fixture-thursday@nodal.test',start='2026-10-01T10:00:00',finish='2026-10-01T12:00:00',rrule='FREQ=WEEKLY;COUNT=10;BYDAY=TH')
for n in range(9):
    day=date(2027,3,1)+timedelta(days=n)
    add('fixture-series-'+str(n),'series',title='Clase sintética '+str(n+1),subject=names[n%5][0],
        category='class',uid='fixture-series-'+str(n),start=str(day)+'T08:00:00',finish=str(day)+'T09:00:00',rrule='FREQ=WEEKLY;COUNT=4')
for n in range(17):
    id=['ac-pl1@nodal.test','sed-pei@nodal.test','ac-pe1@nodal.test'][n] if n<3 else 'fixture-exam-'+str(n)
    add(id,'event',user={'assessment':'no presentado'} if n==0 else {},title='Prueba sintética '+str(n+1),
        subject='AC' if n in (0,2) else 'SED',category='exam',uid=id,
        date='2026-11-03' if n==2 else str(date(2027,5,1)+timedelta(days=n)))
for n in range(60):
    day=date(2027,3,1)+timedelta(days=n)
    id='fixture-study-ac01@nodal.test' if n==0 else 'fixture-study-'+str(n)
    add(id,'event',title='Sesión sintética '+str(n+1),subject='AC',task='AC01' if n==0 else 'AC02',
        category='study',uid=id,location='Biblioteca',start=('2026-10-29' if n==0 else str(day))+'T16:30:00',
        finish=('2026-10-29' if n==0 else str(day))+'T18:00:00')
add('fixture-busy-1','availability',title='Ocupado · ejemplo',days='TH',fromTime='08:00',toTime='16:00')
add('fixture-busy-2','availability',title='Ocupado · ejemplo',days='TU',fromTime='16:00',toTime='17:00')
for n in range(43):
    add('fixture-source-'+str(n),'source',title='Material sintético '+str(n+1),path='material-'+str(n+1)+'.pdf')
assert len(entities)==205
assert len({e['id'] for e in entities})==205
data=dict(snapshot='2026-10-28',context=dict(subjects=[dict(id=s,name=t) for s,t in names],user_confirmations=[],known_conflicts=[]),
          entities=entities,counts={'class':11,'exam':17,'study':60})
(dest/'seed.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('Fixture sintética generada: 205 entidades. No contiene datos del autor.')
