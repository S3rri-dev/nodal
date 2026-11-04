// SPDX-License-Identifier: GPL-3.0-or-later
'use strict';
// Reloj de presentación: no registra asistencia, progreso ni tiempo de estudio.
const CalendarClock = (() => {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Madrid', year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23'
  });
  function now(date = new Date()) {
    const p = Object.fromEntries(formatter.formatToParts(date).map(part => [part.type, part.value]));
    const day = `${p.year}-${p.month}-${p.day}`, time = `${p.hour}:${p.minute}`;
    return { day, time, local: `${day}T${time}:${p.second}`, minute: Number(p.hour) * 60 + Number(p.minute) + Number(p.second) / 60 };
  }
  function local(value) {
    if (!value) return '';
    return /(?:Z|[+-]\d{2}:\d{2})$/.test(value) ? now(new Date(value)).local : value.slice(0, 19).padEnd(19, ':00');
  }
  function active(event, clock = now()) {
    if (event.category === 'availability' || !event.start || !event.finish) return false;
    const start = local(event.start), end = local(event.finish);
    return start < end && start <= clock.local && clock.local < end;
  }
  function position(date, from = 0, to = 1440, scale = .75) {
    const clock = now(date);
    return { ...clock, visible: clock.minute >= from && clock.minute < to, top: (clock.minute - from) * scale };
  }
  function range(anchor, mode) {
    const add = (day, n) => { const d = new Date(day + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
    const monday = day => add(day, -((new Date(day + 'T12:00:00Z').getUTCDay() + 6) % 7));
    const from = mode === 'month' ? monday(anchor.slice(0, 7) + '-01') : add(monday(anchor), -7);
    return { from, to: add(from, mode === 'month' ? 42 : 70) };
  }
  return { now, active, position, range };
})();
if (typeof module !== 'undefined') module.exports = CalendarClock;
