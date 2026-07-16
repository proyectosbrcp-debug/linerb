# LINERB V2 - Sprint 4.3

## Objetivo

Sprint 4.3 consolida el manejo local de exactamente dos fotografías por inspección:

- Foto 1;
- Foto 2.

Las fotografías existen únicamente en el dispositivo móvil, se usan para el PDF local y no forman parte de Firestore, `sync_queue` ni payloads remotos.

## Componentes creados

- `InspectionLocalPhotos`
  - Modelo local tipado.
  - Contiene solo `ownerId`, `photo1LocalPath`, `photo2LocalPath` y fechas locales de captura.
  - No contiene bytes, Base64, URL remota, Firebase Storage ni estado de subida.

- `LocalPhotoStorage`
  - Contrato para guardar, cargar, reemplazar y eliminar referencias locales.

- `FileLocalPhotoStorage`
  - Implementación basada en archivos locales del dispositivo.
  - Guarda un manifiesto JSON local por inspección/borrador.

- `LocalPhotoService`
  - Captura Foto 1 y Foto 2.
  - Copia imágenes temporales a una carpeta administrada por la app.
  - Reemplaza fotos previas.
  - Verifica existencia física.
  - Entrega rutas locales al generador de PDF.
  - No contiene `BuildContext`, `Navigator`, `ScaffoldMessenger` ni widgets.

## Integración

`RegistroInspeccionPage` mantiene el mismo flujo visible y los mismos dos botones:

- `TOMAR FOTO 1`;
- `TOMAR FOTO 2`.

La captura ahora pasa por `LocalPhotoService`, que copia el archivo a almacenamiento local administrado.

`ResumenInspeccionPage` usa `LocalPhotoService.pdfPhotoPaths()` para entregar al PDF máximo dos rutas locales existentes.

## Atomicidad estructurada

El guardado estructurado de inspección, hallazgos y cola de sincronización sigue siendo atómico.

Las fotografías permanecen como archivos locales. Si falla la finalización estructurada, no se eliminan automáticamente.

## Exclusiones

No se agregó Firebase Storage.

No se sincronizan:

- fotografías;
- rutas locales;
- nombres de archivo;
- bytes;
- Base64;
- PDF;
- rutas de PDF.

El dashboard continúa usando solo SQLite y datos estructurados.
