# Contribuir a Nodal

Gracias por ayudar a mejorar la organización de estudio. Antes de un cambio grande, abre una propuesta para acordar el problema y el alcance.

## Preparar el proyecto

Necesitas macOS, Xcode Command Line Tools y Python 3. Las pruebas de JavaScript necesitan un Node existente, detectado en PATH o indicado con NODAL_NODE. No se descargan dependencias para ejecutar la app.

    git clone https://github.com/S3rri-dev/nodal.git
    cd nodal
    ./tests/run.sh
    ./tests/run-ui.sh
    ./scripts/build.sh --dev

La variante Nodal Dev tiene datos propios. Las pruebas de Swift utilizan bases nuevas en build/ y un generador de datos sintéticos. No las apuntes a una base que contenga tus datos.

## Estructura

- Sources/: app nativa, puente WebKit, repositorios SQLite, planificación y validación.
- Resources/web/: interfaz local, reloj, calculadora y materiales visuales.
- Resources/xml/: esquema de planes y ejemplo.
- scripts/: compilación, empaquetado, fixtures y auditoría de publicación.
- tests/: integración de almacenamiento, importación, cronómetros y planificación; reloj y cálculo.
- docs/: manuales, arquitectura, límites y capturas.
- examples/: planes ficticios que puedes importar.
- .github/: CI, publicación y plantillas.

## Proponer un cambio

Explica el problema observable, el comportamiento final y cómo lo comprobaste. Mantén cada pull request enfocado. Utiliza español en la interfaz y conserva la navegación por teclado, el contraste y las preferencias de accesibilidad.

No incluyas calendarios, notas, bases, credenciales, rutas o capturas personales. No registres tiempo ni aprendizaje automáticamente por el paso de una fecha. Las importaciones deben conservar las ediciones y el progreso.

Antes de enviar:

    ./scripts/audit_publication.py
    ./tests/run.sh
    ./tests/run-ui.sh
    ./scripts/build.sh

Los cambios de interacción también necesitan revisión visual nativa. Describe qué verificaste y qué no. No presentes una simulación como una prueba física de suspensión o entrega de notificaciones.

## Licencia de las contribuciones

Al proponer código para este repositorio aceptas que tu contribución se distribuya bajo GPL-3.0-or-later, salvo acuerdo previo expreso. Conserva los avisos existentes. No aportes material de terceros sin permiso o licencia compatible.

La marca Nodal tiene su propia política en TRADEMARKS.md. No se exige una cesión de derechos al mantenedor.
