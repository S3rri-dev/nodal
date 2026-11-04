# Imágenes de Nodal

Las capturas JPG proceden de Resources/web ejecutado con el adaptador de demostración de scripts/browser_preview.py. Muestran exclusivamente asignaturas, notas y dudas ficticias. El bundle oficial comienza vacío.

- today-dark.jpg / today-light.jpg: agenda diaria en ambos temas.
- calendar.jpg: semana con la actividad actual resaltada.
- grades.jpg: media sintética 9,40.
- doubts.jpg: pregunta, intento y referencias de ejemplo.
- hero.png: portada de marca generada con IA, con el icono aprobado como referencia. No es una captura de funciones.

La identidad visual está sujeta a [TRADEMARKS.md](../../TRADEMARKS.md). No incluye imágenes del repositorio de referencia ni el fondo descargado utilizado en la versión personal.

Para reconstruir la demostración: python3 scripts/make_demo.py --date AAAA-MM-DD, python3 scripts/browser_preview.py y un servidor HTTP limitado a build/browser en localhost. Ese servidor no forma parte de la app.
