# Verificación de la publicación 1.6.0

Fecha: 4 de noviembre de 2026. Entorno local: macOS 27.0.1 en ARM64, Apple Swift 6.4. Este documento separa comprobaciones ejecutadas de compatibilidad prevista.

## Pruebas locales ejecutadas

- 135 comprobaciones Swift: calendario y recurrencias, referencias, importaciones, copias, conservación de registros, cronómetro, replanificación, preparación, evaluación y primer arranque público.
- 50 comprobaciones JavaScript: 18 del reloj/calendario y 32 de la calculadora.
- Compilación ARM64 con las herramientas existentes de Apple. Objetivo de despliegue macOS 13.
- Semilla pública vacía y prueba de reapertura sin duplicación.
- XML de ejemplo validado contra el XSD local.
- Revisión de contenido y análisis automatizado de publicación: rutas personales, credenciales detectables, archivos privados y metadatos del bundle. Este análisis no equivale a una auditoría completa de seguridad.

El DMG local se verificó con hdiutil, se montó en modo de solo lectura y se comprobó su firma, metadatos, semilla vacía y primer arranque aislado. Los tres hashes del manifiesto y los paquetes coincidieron con SHA256SUMS.txt.

Comandos reproducibles: tests/run.sh, tests/run-ui.sh, scripts/build.sh y scripts/audit_publication.py.

## Interfaz comprobada

La aplicación nativa Nodal Dev se ejecutó en un Mac Apple Silicon con una base temporal independiente. Se creó la primera asignatura, se guardó una nota de ejemplo 7,50, se comprobó que Enter no añade componentes y se eliminó un segundo componente desde su menú. Guardar y calcular mostró el resultado y SQLite conservó un único componente.

Se importó el XML de ejemplo desde la interfaz nativa: vista previa de 26 elementos, aplicación con copia previa, 26 altas y conservación de la nota anterior. La base de pruebas terminó con integrity_check correcto.

En navegador se revisaron Hoy, calendario semanal con línea actual, calculadora 9,40, duda y temas claro/oscuro. Las capturas del README muestran esos datos sintéticos. La portada es una ilustración de marca generada con IA; no representa funciones adicionales. El navegador usa un adaptador de demostración en memoria; esta revisión no sustituye la persistencia nativa comprobada arriba.

## Automatización en GitHub

CI ejecuta las 50 comprobaciones JavaScript y la auditoría de fuentes en ubuntu-24.04, independientemente de la disponibilidad de macOS. Utiliza por defecto macos-15-intel y macos-26-intel para las 135 comprobaciones Swift y la compilación del producto ARM64. La auditoría comprueba arquitectura, metadatos, semilla y firma de ese producto. scripts/check-bundle.sh ejecuta el arranque con datos aislados: en Intel compila una copia temporal x86_64 del mismo código y recursos; en Apple Silicon ejecuta el binario ARM64. La copia Intel de comprobación permanece en build y no se distribuye.

El disparador manual permite elegir runner_family=arm64 para repetir la comprobación en macos-15 y macos-26 con ejecución del producto ARM64. El resultado vigente de cada commit está en [Actions](https://github.com/S3rri-dev/nodal/actions/workflows/ci.yml); la presencia del workflow no significa que una ejecución haya pasado.

El workflow de release usa macos-26-intel y ejecuta las comprobaciones antes de generar los adjuntos ARM64. Un disparo manual valida y conserva los paquetes como artefacto sin crear una release; solo una etiqueta puede crear el borrador. Cada manifiesto publicado identifica el commit, la arquitectura y los hashes.

## Revisión del escaparate — 4 de noviembre de 2026

Tras enlazar el caso técnico español/inglés se repitieron tests/run.sh (135), tests/run-ui.sh (50), scripts/build.sh y la auditoría del bundle: correctos. No cambia el código de la aplicación ni los paquetes etiquetados.

La ejecución remota [41837435429](https://github.com/S3rri-dev/nodal/actions/runs/41837435429) terminó con resultado global failure; sus trabajos macOS 15/26 aparecen cancelled y no ejecutaron pasos. Las anotaciones de GitHub indican falta de adquisición por un runner hosted y restricciones de capacidad para macOS ARM64. No se atribuyen comprobaciones ejecutadas en esos sistemas.

## Límites explícitos

No se ha probado físicamente en todas las versiones de macOS ni en Mac Intel. No hay prueba física certificada de suspensión y reanudación de este paquete. Tampoco auditoría exhaustiva de accesibilidad o seguridad. La versión se firma ad hoc; no tiene Developer ID, notarización ni distribución por App Store.

La base no tiene cifrado propio ni sincronización. La interfaz es española y el calendario usa Europe/Madrid. La aplicación instalada no precisa el servidor local utilizado exclusivamente para capturas durante el desarrollo.


## Revisión de CI — 4 de noviembre de 2026

Las anotaciones de 41837435429 indicaron que los trabajos no fueron adquiridos por ejecutores hosted y notificaron restricciones de capacidad para macOS ARM64. Se lanzó una nueva comprobación ARM64 sobre 34d0f35 para revisar la situación. Se preparó en codex/ci-macos-capacity una alternativa Intel y un trabajo Linux independiente, manteniendo el producto ARM64. Las comprobaciones de ejecución de ambas arquitecturas se describen por separado.

Validación local de la propuesta: 135 Swift + 50 JavaScript, compilación ARM64, auditoría y arranque aislado correctos; YAML de ambos workflows válido. También se compiló y firmó la copia de comprobación x86_64. Esa compilación produjo avisos por una librería de compatibilidad de la instalación local que solo contiene ARM; no se ejecutó la copia Intel ni se instaló Rosetta.

A las 18:35 Europe/Madrid, la [CI alternativa 41877783472](https://github.com/S3rri-dev/nodal/actions/runs/41877783472) seguía en cola con tres trabajos sin ejecutor y sin pasos: Linux, macOS 15 Intel y macOS 26 Intel. El [ensayo de empaquetado 41877293656](https://github.com/S3rri-dev/nodal/actions/runs/41877293656) tampoco había empezado. Actions estaba habilitado y las etiquetas eran válidas. El panel general de GitHub figuraba operativo; no se confirmó la causa de esta espera más amplia.

Se mantiene la propuesta sin integrar en main hasta disponer de ejecución remota. No se presentan esas plataformas como superadas. Este cambio no altera la app ni los adjuntos de v1.6.0.


## Avance de la validación remota

Tras refrescar los resultados de GitHub, la CI 41877783472 muestra JavaScript/auditoría Linux y verificación macos-26-intel superadas; macos-15-intel sigue queued sin pasos. El ensayo de empaquetado 41877293656 ha terminado success: ejecutó 135 comprobaciones Swift y 50 JavaScript, compilación ARM64, arranque de la copia Intel, empaquetado y subida del artefacto. El paso de crear una release quedó omitido, como corresponde a un ensayo manual.

Se descargó el artefacto nodal-release (13348240542). Sus cuatro adjuntos coinciden con SHA256SUMS y el manifiesto referencia 5c93ece6253314dc30ce493840567698938fee15. El DMG se montó en lectura en un Mac Apple Silicon: auditoría de metadatos/arquitectura/semilla y firma correctas; el binario ARM64 generado por GitHub ejecutó --check con una base aislada vacía. Así se distingue la ejecución Intel remota de la ejecución ARM64 local del artefacto remoto.

El incidente oficial https://www.githubstatus.com/incidents/h02n9572mx9y comenzó a las 18:40 Europe/Madrid del 4 de noviembre y figura investigating, con impacto major, en la comprobación realizada. La API del incidente confirma disponibilidad degradada de Actions. Durante este periodo los resultados agregados pueden tardar en reflejar los pasos terminados; las observaciones de cola anteriores se conservan como tales.

Pendiente: resultado de macOS 15 y cierre de la incidencia. La propuesta sigue en borrador y main y la release v1.6.0 permanecen sin modificar.
