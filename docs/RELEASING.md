# Publicar una versión

La publicación oficial se realiza desde S3rri-dev/nodal. Usa la cuenta mantenedora y verifica su identidad antes de escribir en GitHub. No introduzcas tokens en comandos, archivos ni URLs.

## Preparar

1. Actualiza la versión y compilación de scripts/build.sh.
2. Actualiza CHANGELOG.md y crea docs/releases/VERSION.md con funciones y límites reales.
3. Revisa LICENSE, TRADEMARKS.md y THIRD_PARTY_NOTICES.md. Usa únicamente datos sintéticos en ejemplos y capturas.
4. Ejecuta las comprobaciones, compila y revisa la interfaz nativa con una base de pruebas separada:

       python3 scripts/audit_publication.py
       ./tests/run.sh
       ./tests/run-ui.sh
       ./scripts/build.sh
       ./scripts/check-bundle.sh

5. Comprueba que la carpeta de datos es Nodal y que el bundle no contiene MUTestDataDirectory. No empaquetes un bundle modificado para pruebas.
6. Registra el resultado y sus límites en VERIFICATION.md; confirma el código y los documentos en Git.

## Empaquetar y etiquetar

Desde un commit limpio y comprobado:

    ./scripts/package.sh

Produce DMG para ARM64, ZIP del código de HEAD, manifiesto con commit y hashes, y SHA256SUMS.txt. El código ZIP contiene los avisos y fuentes, sin herramientas locales, bases ni artefactos de build. Revisa los hashes desde dist con shasum -a 256 -c SHA256SUMS.txt.

Tras publicar main y comprobar CI:

    git tag vVERSION
    git push origin vVERSION

El workflow release.yml utiliza macos-26-intel, valida que etiqueta y versión coinciden, repite pruebas, compila el producto ARM64, lo audita, empaqueta y crea una **release en borrador**. En Intel, la comprobación de arranque utiliza una copia temporal x86_64 del mismo código y recursos; la ejecución del binario ARM64 requiere Apple Silicon.

Para validar el workflow sin crear ni modificar una release, ejecútalo con workflow_dispatch sobre la rama que quieras comprobar. Conserva los cuatro adjuntos como artefacto de Actions. Solo el disparador de etiqueta crea el borrador. Las acciones están fijadas por SHA; el permiso de escritura queda en el trabajo de release. No se sobrescriben etiquetas publicadas.

## Revisar el borrador

Comprueba el trabajo de Actions, descarga los cuatro adjuntos y verifica sus hashes. Monta el DMG en modo de solo lectura y comprueba bundle, licencia, semilla vacía y firma ad hoc. El manifiesto identifica el commit; los builds no prometen igualdad binaria reproducible entre SDK distintos.

Cuando los adjuntos y las notas sean correctos, publica el borrador desde GitHub o con gh release edit vVERSION --draft=false --latest. Verifica la descarga sin sesión y los enlaces del README.

La release actual utiliza firma ad hoc, sin Developer ID ni notarización. Los hashes detectan cambios respecto al manifiesto publicado, pero no sustituyen una identidad de desarrollador de Apple. No presentes el resultado como notarizado, como Universal o como probado físicamente en todas las versiones de macOS.
