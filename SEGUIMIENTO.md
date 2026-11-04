# Seguimiento de la publicación

## 4 de noviembre de 2026 — revisión de CI

Diagnóstico confirmado mediante API: los trabajos ARM64 de 41837435429 no ejecutaron pasos y GitHub notificó restricciones de capacidad. Nueva comprobación ARM64 41876859354 sobre 34d0f35. Se prepara un trabajo Linux independiente para JavaScript/auditoría y CI Intel para pruebas nativas y compilación cruzada ARM64; arranque mediante copia temporal de la arquitectura del ejecutor, sin cambiar los adjuntos publicados. Release manual conserva artefactos sin publicar; el disparador de etiqueta sigue creando solo un borrador. Pendiente: validar localmente, ejecutar la alternativa en GitHub y registrar sus resultados.

## 4 de noviembre de 2026 — escaparate de ingeniería

Se enlaza desde los README español/inglés el caso técnico del perfil S3rri-dev: problema, arquitectura, decisiones de importación y cronómetro, código y comprobaciones. Se actualizan descripción y temas del repositorio. No cambia la implementación ni la versión publicada.

Se repitieron 135 comprobaciones Swift, 50 JavaScript, compilación ARM64 y auditoría de fuentes/bundle: correctas. La revisión de presentación corresponde a GitHub; esta actualización documental no añade una nueva prueba física de suspensión ni compatibilidad.

CI 41837435429 terminó con resultado global failure y trabajos cancelled, sin ejecutar pasos: GitHub informó que ningún ejecutor hosted adquirió los trabajos y notificó restricciones de capacidad macOS ARM64. No es evidencia de pruebas remotas superadas ni de una ejecución de las pruebas con fallo. Se mantiene visible el enlace a Actions. La actualización documental usa skip ci para no volver a encolar compilaciones sin cambios de código.

## 4 de noviembre de 2026 — versión pública 1.6.0

Decisiones: repositorio e historial limpios, cuenta mantenedora S3rri-dev, código GPL-3.0-or-later e identidad reservada. Semilla vacía; ejemplos y fixtures independientes y sintéticos. Bundle oficial io.github.s3rri-dev.nodal; desarrollo con identificador y datos propios. Firma ad hoc, sin promesa de notarización.

Preparación: se reutilizaron Swift, frameworks y SQLite del sistema, Python, Node y herramientas de empaquetado existentes. GitHub CLI se usa con un perfil dedicado y credenciales en Keychain. La ejecución de la app no descarga dependencias.

Comprobaciones locales: tests/run.sh (135), tests/run-ui.sh (50), build ARM64, XML válido y revisión nativa de arranque, componentes y cálculo, más importación con copia y conservación de nota. Resultado de integridad SQLite: correcto. Se revisaron cinco pantallas/estados con datos ficticios para documentar la interfaz.

Publicación: los workflows ci.yml y release.yml registran sus resultados por commit y etiqueta en GitHub Actions. El proceso de empaquetado genera DMG, fuentes, manifiesto y hashes. El historial de versiones y sus adjuntos se consultan en Releases.

Siguiente paso de mantenimiento: atender incidencias reproducibles y ampliar comprobaciones físicas y accesibilidad. Firma Developer ID y notarización figuran como trabajo futuro; no se presentan como resueltas.
