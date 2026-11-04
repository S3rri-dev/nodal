# Plan, progreso y copias

Los elementos del plan, sus ediciones locales y los registros del usuario se almacenan por separado. Cambiar el plan no debe borrar tus notas, tiempos, dudas o estados.

## Formatos

- XML: plan y relaciones completas. XSD y contrato en XML.md.
- ICS: eventos, series y excepciones del calendario. No es sincronización.
- SQLite: copia completa de los datos, incluidos registros personales.
- Markdown/texto: contexto y dudas para compartir deliberadamente.

## Copias

Ajustes → Copias de seguridad permite crear/exportar y restaurar. Antes de importar o restaurar se guarda una copia consistente con la API de backup de SQLite. Restaurar exige finalizar el cronómetro y crea otra copia del estado anterior.

Comprueba que tu copia se puede abrir antes de depender de ella como única recuperación. Nodal no realiza copias en la nube.

## Actualizar un plan

Abre un XML, valida, revisa cambios y conflictos y aplica. La ausencia de un ID no lo elimina; archivar debe ser explícito. La misma revisión y contenido es idempotente. Si cambian datos después de la vista previa, hay que revisarla de nuevo.

Para las reglas y los límites exactos, consulta XML.md y el esquema de Resources/xml/.
