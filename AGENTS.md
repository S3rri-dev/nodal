# Nodal

- Trabajar en español. Mantener cambios concretos y verificables.
- Aplicación macOS ARM64 local: Swift, AppKit/WebKit y SQLite del sistema. Sin cuentas, servidor, telemetría ni dependencias de ejecución descargadas.
- La semilla pública de Resources/seed.json debe permanecer vacía. Usar ejemplos sintéticos; nunca incorporar planes, rutas, registros ni capturas personales.
- Separar datos de plan, ediciones locales y progreso. No inferir notas, aprendizaje ni tiempo por una fecha pasada.
- Madrid, formato de 24 horas y lunes primero. Hoy usa el reloj real.
- Datos persistentes en Application Support/Nodal; desarrollo en Nodal Dev. No abrir la base de otra instancia para probar.
- XML: XSD local, sin DTD ni entidades, límites, referencias, preview, transacción, idempotencia y copia SQLite consistente.
- Conservar un único cronómetro por base; excluir suspensión, cierre y ausencia dudosa.
- Ejecutar tests/run.sh, tests/run-ui.sh y scripts/build.sh. Revisar la interfaz nativa cuando cambie su comportamiento.
- Reutilizar las herramientas disponibles. Node solo verifica la interfaz; la app instalada no lo necesita.
- No afirmar firma Developer ID, notarización, compatibilidad física o pruebas que no se hayan realizado.
- Código GPL-3.0-or-later; identidad según TRADEMARKS.md.
- Para publicar como mantenedor, verificar identidad S3rri-dev y usar un perfil de GitHub dedicado. No incluir credenciales en archivos o URLs.
- No delegar a subagentes sin petición explícita.
