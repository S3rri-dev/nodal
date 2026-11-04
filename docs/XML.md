# Intercambiar y actualizar planes

El formato conserva identificadores estables para actualizar el plan sin sustituir los registros personales. El contrato completo es [plan-v1.xsd](../Resources/xml/plan-v1.xsd); [plan-demo.xml](../examples/plan-demo.xml) es un ejemplo ficticio importable.

## Importación

1. Abre Ajustes → Importar y exportar plan → Abrir actualización XML.
2. Selecciona el archivo o pega su ruta.
3. Pulsa Validar y revisar. Comprueba las altas, cambios, archivos y conflictos.
4. Elige entre conservar la edición local y aceptar el plan entrante cuando exista un conflicto.
5. Pulsa Aplicar con copia. La aplicación crea una copia consistente y aplica todo en una transacción.

Cerrar la vista previa no aplica el plan. Si cambia la base desde la vista previa, hay que validarla de nuevo. Repetir el mismo paquete y revisión con el mismo contenido no duplica sus elementos. Modificar una revisión ya aplicada exige un número nuevo; también se rechazan revisiones antiguas.

## Estructura

~~~xml
<?xml version="1.0" encoding="UTF-8"?>
<universidad version="1" paquete="mi-plan" revision="1"
 zona="Europe/Madrid" fechaRevision="2026-11-04">
  <elemento id="MAT" tipo="subject">
    <title>Matemáticas</title>
    <color>#D8B56A</color>
  </elemento>
  <elemento id="MAT-examen" tipo="event">
    <title>Primer parcial</title>
    <subject>MAT</subject>
    <category>exam</category>
    <date>2026-11-11</date>
  </elemento>
</universidad>
~~~

La raíz exige versión 1, zona Europe/Madrid, paquete, revisión entera positiva y fechaRevision. Los tipos admitidos son subject, topic, task, series, event, occurrence, source y availability. Los nombres internos en inglés forman parte del formato; la interfaz se presenta en español.

Los IDs no se cambian al renombrar. subject, topic, task, evaluation y series deben apuntar al tipo correspondiente. Las dependencias de tareas no admiten referencias a sí mismas ni ciclos. El tema de una tarea debe pertenecer a su asignatura.

Un evento utiliza date si no tiene hora o start y finish para un intervalo. Los timestamps incluyen zona u offset, por ejemplo 2026-11-11T10:00:00+01:00. No se deben combinar date y start. Las sesiones study requieren final posterior al inicio. Las recurrencias usan el subconjunto de RRULE admitido por el calendario; no se promete compatibilidad completa con todos los proveedores ICS.

## Conservar el progreso

El XML intercambia campos de planificación. Las notas, dudas, intentos, registros de tiempo y estados personales permanecen en la base. Omitir un elemento del archivo no lo elimina: para archivarlo se envía su mismo ID con accion="archivar"; para recuperarlo, accion="reactivar". Las bajas con historial o ediciones locales se revisan como conflictos.

La exportación XML contiene el plan y puede incluir nombres y rutas que tú hayas añadido. Revísala antes de compartirla. Una copia SQLite contiene más información personal que el XML; [consulta los datos y copias](DATA.md).

## Límites y validación

El lector exige UTF-8 y hasta 2 MB; limita profundidad a 8, nodos a 30.000 y texto por campo a 100.000 bytes. El XSD limita a 5.000 elementos. Rechaza DTD, declaraciones de entidades, esquemas externos y XInclude. Usa el XSD local y xmllint con --nonet, además de validación de referencias y reglas del plan.

Para comprobar la sintaxis del ejemplo en un Mac:

    xmllint --nonet --noout --schema Resources/xml/plan-v1.xsd examples/plan-demo.xml

Validar con xmllint no sustituye la validación referencial de Nodal ni la revisión del usuario.
