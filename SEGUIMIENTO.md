# Seguimiento de la publicación

## 4 de noviembre de 2026 — versión pública 1.6.0

Decisiones: repositorio e historial limpios, cuenta mantenedora S3rri-dev, código GPL-3.0-or-later e identidad reservada. Semilla vacía; ejemplos y fixtures independientes y sintéticos. Bundle oficial io.github.s3rri-dev.nodal; desarrollo con identificador y datos propios. Firma ad hoc, sin promesa de notarización.

Preparación: se reutilizaron Swift, frameworks y SQLite del sistema, Python, Node y herramientas de empaquetado existentes. GitHub CLI se usa con un perfil dedicado y credenciales en Keychain. La ejecución de la app no descarga dependencias.

Comprobaciones locales: tests/run.sh (135), tests/run-ui.sh (50), build ARM64, XML válido y revisión nativa de arranque, componentes y cálculo, más importación con copia y conservación de nota. Resultado de integridad SQLite: correcto. Se revisaron cinco pantallas/estados con datos ficticios para documentar la interfaz.

Publicación: los workflows ci.yml y release.yml registran sus resultados por commit y etiqueta en GitHub Actions. El proceso de empaquetado genera DMG, fuentes, manifiesto y hashes. El historial de versiones y sus adjuntos se consultan en Releases.

Siguiente paso de mantenimiento: atender incidencias reproducibles y ampliar comprobaciones físicas y accesibilidad. Firma Developer ID y notarización figuran como trabajo futuro; no se presentan como resueltas.
