# Seguimiento de la publicación

## 4 de noviembre de 2026 — revisión de CI

Diagnóstico confirmado mediante API: los trabajos ARM64 de 41837435429 no ejecutaron pasos y GitHub notificó restricciones de capacidad. Nueva comprobación ARM64 41876859354 sobre 34d0f35. Se prepara un trabajo Linux independiente para JavaScript/auditoría y CI Intel para pruebas nativas y compilación cruzada ARM64; arranque mediante copia temporal de la arquitectura del ejecutor, sin cambiar los adjuntos publicados. Release manual conserva artefactos sin publicar; el disparador de etiqueta sigue creando solo un borrador. Validación local: 135 Swift + 50 JavaScript, build ARM64, auditoría y arranque aislado correctos; sintaxis YAML correcta. Copia x86_64 compilada y firmada con avisos de compatibilidad del SDK local, sin ejecutarla.

La CI alternativa 41877783472 y el empaquetado manual 41877293656 se han lanzado. A las 18:35 seguían sin ejecutor ni pasos, también en Linux e Intel. Se solicitaron cancelaciones de las ejecuciones anteriores sustituidas para evitar duplicados; no se confunde solicitud con cancelación completada.

Pendiente externo: asignación de ejecutores por GitHub. Propuesta conservada en rama de prueba, sin integrar ni modificar la release. Registrar el resultado remoto cuando se produzca.

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


## Avance de la validación remota

Tras refrescar los resultados de GitHub, la CI 41877783472 muestra JavaScript/auditoría Linux y verificación macos-26-intel superadas; macos-15-intel sigue queued sin pasos. El ensayo de empaquetado 41877293656 ha terminado success: ejecutó 135 comprobaciones Swift y 50 JavaScript, compilación ARM64, arranque de la copia Intel, empaquetado y subida del artefacto. El paso de crear una release quedó omitido, como corresponde a un ensayo manual.

Se descargó el artefacto nodal-release (13348240542). Sus cuatro adjuntos coinciden con SHA256SUMS y el manifiesto referencia 5c93ece6253314dc30ce493840567698938fee15. El DMG se montó en lectura en un Mac Apple Silicon: auditoría de metadatos/arquitectura/semilla y firma correctas; el binario ARM64 generado por GitHub ejecutó --check con una base aislada vacía. Así se distingue la ejecución Intel remota de la ejecución ARM64 local del artefacto remoto.

El incidente oficial https://www.githubstatus.com/incidents/h02n9572mx9y comenzó a las 18:40 Europe/Madrid del 4 de noviembre y figura investigating, con impacto major, en la comprobación realizada. La API del incidente confirma disponibilidad degradada de Actions. Durante este periodo los resultados agregados pueden tardar en reflejar los pasos terminados; las observaciones de cola anteriores se conservan como tales.

Pendiente: resultado de macOS 15 y cierre de la incidencia. La propuesta sigue en borrador y main y la release v1.6.0 permanecen sin modificar.
