# LINERB V2 - Sprint 4.1

## Objetivo

Sprint 4.1 prepara la base local para sincronización futura entre dispositivos, sin conectar Firebase, backend, red ni autenticación.

## Alcance implementado

- Metadatos de sincronización en `inspections`.
- Metadatos de sincronización en `hallazgos`.
- Tabla local `sync_queue`.
- Contratos:
  - `SyncQueueStorage`;
  - `SyncMetadataStorage`;
  - `SyncRepository`;
  - `RemoteSyncDataSource`.
- Implementación SQLite local de cola:
  - insertar pendientes;
  - consultar pendientes;
  - marcar completadas;
  - registrar fallo;
  - incrementar intentos;
  - reprogramar reintento;
  - detectar duplicados;
  - compactar operaciones compatibles.
- `DeviceIdentityService` para generar un `device_id` estable por instalación.
- `Clock` inyectable para timestamps deterministas.

## Cambios SQLite

La base pasa a versión 3.

Columnas agregadas a `inspections` y `hallazgos`:

- `global_id`;
- `created_at`;
- `updated_at`;
- `created_by`;
- `updated_by`;
- `device_id`;
- `local_version`;
- `remote_version`;
- `sync_status`;
- `last_sync_at`;
- `deleted_at`.

Tabla nueva:

```text
sync_queue
  id
  entity_type
  entity_id
  operation
  payload_json
  attempts
  next_attempt_at
  last_error
  created_at
  updated_at
  is_conflict
```

## Atomicidad

El guardado de una inspección finalizada confirma dentro de una sola transacción:

- inspección;
- hallazgos asociados;
- operaciones `pendingCreate` de la cola.

Si falla la cola, no queda una inspección parcial marcada como sincronizable.

## Borrador

El borrador permanece exclusivamente local.

Justificación: contiene estado temporal de trabajo en curso, puede incluir rutas locales de fotos y no representa todavía una inspección finalizada ni auditable.

## Backend

No se conectó ningún backend.

`RemoteSyncDataSource` existe solo como interfaz para una implementación futura.
