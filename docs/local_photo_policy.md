# Política local de fotografías

## Decisión funcional

Las fotografías son completamente locales.

Cada inspección maneja exactamente 2 fotografías dentro del flujo móvil actual. No hay zoom.

## Uso permitido

Las fotografías se usan únicamente para generar el PDF local desde el dispositivo.

SQLite puede conservar rutas locales cuando son necesarias para restaurar el flujo local o generar el PDF.

## Exclusiones de sincronización

No se sincronizan:

- archivos de fotografía;
- bytes de imagen;
- imágenes en base64;
- rutas locales de fotografías;
- PDF generado;
- archivos adjuntos locales.

Las fotografías no forman parte de `sync_queue`.

Las rutas locales no forman parte del payload remoto futuro.

El PDF tampoco se sincroniza.

## Comportamiento entre dispositivos

Otro dispositivo verá los datos estructurados sincronizables, como línea, responsable, fecha, coordenadas, observaciones y hallazgos.

Ese otro dispositivo no verá las fotografías ni el PDF generado en el dispositivo original.

## Dashboard

El dashboard continúa dependiendo únicamente de datos estructurados.

No depende de fotografías, rutas locales, archivos ni PDF.
