# Política local de PDF

## Uso de fotografías

El PDF local puede incluir exactamente Foto 1 y Foto 2 por hallazgo/inspección según las rutas locales disponibles.

Las imágenes se leen desde el dispositivo.

El PDF no depende de internet ni de Firestore.

## Exclusión de sincronización

El PDF generado:

- no se almacena en SQLite;
- no se agrega a `sync_queue`;
- no se sube a Firestore;
- no se sube a Firebase Storage;
- no se sincroniza entre dispositivos.

## Comportamiento entre dispositivos

Otro dispositivo podrá recibir datos estructurados de inspecciones y hallazgos.

Ese dispositivo no podrá reconstruir:

- fotografías originales;
- rutas locales;
- PDF generado en el dispositivo original.

## Dashboard

El dashboard no depende de:

- cantidad de fotografías;
- existencia de archivos locales;
- rutas fotográficas;
- generación del PDF.
