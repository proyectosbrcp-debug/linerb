# Ciclo local de fotografías

## Captura

El usuario captura únicamente:

- Foto 1;
- Foto 2.

No existe tercer espacio fotográfico.

No se implementa zoom, recorte, filtros, rotación, anotaciones ni edición.

## Ubicación administrada

Después de capturar, `LocalPhotoService` copia la imagen desde la ubicación temporal de cámara hacia:

```text
<directorio de documentos de la app>/linerb_local_photos/<ownerId>/
```

`ownerId` puede representar un borrador o inspección local.

Los nombres se generan localmente con identificadores estables y sin datos sensibles.

## Reemplazo

El usuario puede reemplazar Foto 1 o Foto 2 antes de finalizar.

Cuando se reemplaza una foto, la referencia local se actualiza y el archivo anterior se elimina solo si es seguro.

## Borrador

El borrador conserva las rutas locales dentro de los hallazgos.

Al restaurar un borrador:

- si la ruta existe, se conserva;
- si un archivo ya no existe, solo ese espacio queda pendiente;
- el resto del borrador no se destruye.

## Finalización

Al finalizar:

- se guarda la inspección estructurada;
- se guardan hallazgos y cola de sincronización;
- el PDF usa rutas locales existentes;
- el borrador se borra solo después de completarse correctamente el flujo de guardado.

Si falla la finalización, las fotos locales y el borrador se conservan.

## Limpieza

Se eliminan archivos temporales copiados cuando es seguro.

No se realiza limpieza destructiva automática de fotografías asociadas a inspecciones finalizadas.
