# Instalación y requisitos

## Descargar

Las versiones oficiales se publican exclusivamente en https://github.com/S3rri-dev/nodal/releases. Descarga el DMG ARM64 y, si quieres comprobar su integridad, compara el archivo SHA256SUMS.txt de esa misma versión.

    shasum -a 256 Nodal-1.6.0-arm64.dmg

Abre el DMG y arrastra Nodal.app a Aplicaciones. La app funciona sin servidor ni instalación de Python o Node. Abre Nodal y crea tu primera asignatura.

## Requisitos y alcance comprobado

- Mac con Apple Silicon. No se ofrece binario Intel.
- Objetivo de compilación: macOS 13 o posterior.
- Las plataformas ejecutadas están en [VERIFICATION.md](VERIFICATION.md). Un objetivo de compilación no equivale a haber probado todos esos sistemas.
- La interfaz actual está en español y utiliza Europe/Madrid.

## Firma de esta versión

La distribución inicial está firmada ad hoc. No tiene certificado Developer ID ni notarización de Apple. Una suma SHA-256 comprueba integridad, no identifica por sí sola al editor.

macOS puede impedir la primera apertura. Lee el aviso y, solo si decides confiar en la procedencia, sigue la opción oficial Abrir igualmente en Ajustes del Sistema → Privacidad y seguridad. No desactives Gatekeeper ni otras protecciones para instalarla.

Guía oficial de Apple: https://support.apple.com/es-es/102445

## Actualizar y conservar tus datos

Crea una copia desde Ajustes antes de sustituir la app. La base pública está en ~/Library/Application Support/Nodal/universidad.sqlite; no está dentro del bundle.

La antigua versión personal de desarrollo utilizaba otra carpeta e identificador. La versión pública no busca ni importa esos datos automáticamente. Importa un plan XML o restaura deliberadamente una copia compatible si quieres trasladarlos.

## Desinstalar

Cierra la app y mueve Nodal.app a la Papelera. Esto conserva tus datos. Si quieres borrarlos, exporta primero una copia y elimina deliberadamente la carpeta Application Support/Nodal. Esta operación afecta a tus registros.
