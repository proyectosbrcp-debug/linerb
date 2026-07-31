# Clasificación de errores de sincronización

Servicio: `SyncErrorClassifier`.

Categorías:

- `network`
- `unavailable`
- `timeout`
- `authentication`
- `permission`
- `invalidData`
- `conflict`
- `localStorage`
- `remoteStorage`
- `rateLimited`
- `unknown`

Los códigos técnicos de Firebase se mapean internamente y no se muestran en UI.

Mensajes amigables:

- Sin conexión: los datos permanecen guardados en el dispositivo.
- Sesión requerida: la sesión debe renovarse.
- Permiso insuficiente: el usuario no tiene permiso para enviar cambios.
- Error transitorio: se volverá a intentar automáticamente.
- Datos inválidos: algunos datos requieren revisión.

## Datos que no se registran

No se registran:

- contraseñas;
- ID tokens;
- refresh tokens;
- API keys;
- payloads completos;
- descripciones completas;
- bytes;
- fotografías;
- rutas locales;
- PDF;
- URL completa de Google Maps.
