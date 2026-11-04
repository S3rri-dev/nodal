const assert = require('node:assert/strict');
const clock = require('../Resources/web/calendar-clock.js');
let passed = 0;
function check(label, fn) { fn(); passed++; console.log('✓ ' + label); }
const at = value => clock.now(new Date(value));
const event = { category: 'study', start: '2026-10-29T10:00:00', finish: '2026-10-29T12:00:00' };
check('Madrid en invierno, independiente de la zona del equipo', () => assert.equal(at('2026-10-29T09:30:00Z').time, '10:30'));
check('Madrid en verano', () => assert.equal(at('2026-07-29T08:30:00Z').time, '10:30'));
check('inicio del horario de verano', () => assert.equal(at('2026-03-29T01:00:00Z').time, '03:00'));
check('las dos horas repetidas en otoño conservan hora local', () => {
  assert.equal(at('2026-10-25T00:30:00Z').time, '02:30');
  assert.equal(at('2026-10-25T01:30:00Z').time, '02:30');
});
check('intervalo activo incluye inicio', () => assert.equal(clock.active(event, at('2026-10-29T09:00:00Z')), true));
check('intervalo activo excluye fin', () => assert.equal(clock.active(event, at('2026-10-29T11:00:00Z')), false));
check('otra fecha con la misma hora no se resalta', () => assert.equal(clock.active(event, at('2026-10-30T09:30:00Z')), false));
check('un evento futuro no se resalta', () => assert.equal(clock.active(event, at('2026-10-29T08:59:59Z')), false));
check('fecha sin hora no se convierte en evento activo', () => assert.equal(clock.active({date:'2026-10-29'}, at('2026-10-29T09:30:00Z')), false));
check('fin desconocido no inventa duración activa', () => assert.equal(clock.active({...event, finish:undefined}, at('2026-10-29T09:30:00Z')), false));
check('disponibilidad no se confunde con actividad actual', () => assert.equal(clock.active({...event, category:'availability'}, at('2026-10-29T09:30:00Z')), false));
check('sesión que cruza medianoche', () => assert.equal(clock.active({category:'study',start:'2026-10-29T23:45:00',finish:'2026-10-30T00:30:00'},at('2026-10-29T23:00:00Z')),true));
check('eventos con zona explícita se comparan en Madrid', () => assert.equal(clock.active({...event,start:'2026-10-29T09:00:00Z',finish:'2026-10-29T11:00:00Z'},at('2026-10-29T09:30:00Z')),true));
check('línea avanza con los segundos', () => {
 const first=clock.position(new Date('2026-10-29T09:30:00Z')),next=clock.position(new Date('2026-10-29T09:31:00Z'));
 assert.equal(next.top-first.top,.75);assert.equal(first.top,472.5);
});
check('medianoche muestra línea al principio del nuevo día', () => {
 const p=clock.position(new Date('2026-10-29T23:00:00Z'));assert.equal(p.day,'2026-10-30');assert.equal(p.top,0);
});
check('vista mensual incluye las seis semanas completas, también las primeras', () => assert.deepEqual(clock.range('2026-10-29','month'),{from:'2026-09-28',to:'2026-11-09'}));
check('mes con cambio de año', () => assert.deepEqual(clock.range('2027-01-31','month'),{from:'2026-12-28',to:'2027-02-08'}));
check('misma consulta mensual desde cualquier día del mes', () => assert.deepEqual(clock.range('2026-10-01','month'),clock.range('2026-10-29','month')));
console.log(passed+' comprobaciones de reloj y calendario superadas.');
