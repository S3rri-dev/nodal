# Seguridad

## Versiones

La serie pública 1.6.x recibe correcciones. No se promete un plazo de respuesta ni una auditoría de seguridad completa.

## Comunicar una vulnerabilidad

Utiliza [Report a vulnerability](https://github.com/S3rri-dev/nodal/security/advisories/new) para enviar un aviso privado al mantenedor. Describe versión, pasos mínimos e impacto esperado. Evita adjuntar bases o datos académicos reales.

Para un fallo funcional ordinario, utiliza una incidencia pública. No publiques detalles de una vulnerabilidad sin dar al mantenedor oportunidad de revisarla.

## Superficie relevante

Planes XML y calendarios ICS, restauración SQLite, apertura explícita de materiales locales y puente WebKit. El XML se valida contra XSD local y rechaza DTD/entidades externas. La interfaz aplica CSP sin conexiones de red.

Los avisos de privacidad y los permisos reales están documentados en docs/PRIVACY.md y docs/PERMISSIONS.md.
