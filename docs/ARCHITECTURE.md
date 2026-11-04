# Arquitectura

## Capas

    AppKit / NSApplication
      └─ WKWebView local + puente de mensajes
          └─ Store y servicios de dominio
              └─ SQLite del sistema y archivos elegidos

- main.swift / Appearance.swift: ventana, menús, archivos, recordatorios, accesibilidad y puente.
- Support.swift: fechas, JSON, errores y acceso SQLite.
- Store.swift: migraciones, entidades, ediciones y datos de usuario.
- Calendar.swift: ICS, recurrencias y excepciones.
- Timer.swift: segmentos con marcas temporales, heartbeat y recuperación.
- Import.swift / Planning.swift: esquema, preview, referencias y transacciones.
- Replanning.swift / Preparation.swift: lotes revisables y ficha de pruebas.
- Grades.swift y grades-model.js: validación y cálculo.
- Resources/web/: presentación HTML/CSS/JS sin servidor.

## Persistencia

Las migraciones están versionadas. Las entidades separan plan, local y user; los registros de tiempo, dudas, intentos, revisiones e importaciones conservan su historia. La semilla solo se aplica una vez y la pública está vacía.

## Fronteras

WebKit no navega a contenido remoto y la CSP impide conexiones. El XML se procesa como datos con XSD local, sin DTD/entidades, límites y validación referencial. La restauración usa backup SQLite y valida integridad.

## Tiempo y aprendizaje

El reloj no concede asistencia, progreso ni conocimiento. Los cronómetros calculan segmentos, no suman ticks de JavaScript. Una tarea completada y una evidencia de aprendizaje son registros diferentes.

## Variantes

La versión pública usa io.github.s3rri-dev.nodal y Application Support/Nodal. La variante Dev usa otro identificador y Nodal Dev. NODAL_DATA permite una ruta de prueba deliberada. El paquete oficial nunca contiene esa ruta de prueba.
