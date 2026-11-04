# Privacidad

Nodal guarda datos académicos localmente: plan, tareas, estados, notas, dudas, intentos, tiempo, preferencias y copias.

La aplicación no incluye cuentas, analítica, anuncios, seguimiento, actualización automática ni servicios de nube. La interfaz WebKit carga archivos del bundle y bloquea conexiones mediante CSP. El repositorio y sus imágenes de GitHub no forman parte de la ejecución de la app.

## Ubicaciones

- Público: ~/Library/Application Support/Nodal/.
- Desarrollo: ~/Library/Application Support/Nodal Dev/.
- Las pruebas utilizan carpetas nuevas en build/ o una ruta de datos explícita.

La base no incorpora cifrado propio ni contraseña. Depende de los permisos de tu cuenta de macOS y de las protecciones del equipo; no se promete protección frente a otra persona con acceso a tu sesión o a tus archivos.

## Acciones explícitas

Los planes y calendarios se importan/exportan como archivos. Al exportar dudas, notas o copias, tú decides dónde compartirlos. Las copias SQLite contienen registros personales: no las publiques en incidencias.

Abrir un material lo entrega al visor del sistema. Los recordatorios, si los activas y autorizas, se envían al sistema de notificaciones de macOS. No se accede a calendarios externos.

Las capturas del repositorio contienen ejemplos ficticios. La semilla del producto está vacía y no incluye la planificación del autor.
