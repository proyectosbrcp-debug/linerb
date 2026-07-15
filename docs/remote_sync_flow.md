# Flujo de sincronización remota

## Envío

1. La app guarda inspecciones y hallazgos en SQLite.
2. Sprint 4.1 crea operaciones pendientes en `sync_queue`.
3. Sprint 4.2 expone `SyncWorker.syncNow()`.
4. `syncNow()` lee operaciones en orden.
5. Envía datos estructurados por `RemoteSyncDataSource`.
6. Si el envío funciona:
   - elimina la operación de cola;
   - actualiza `remote_version`;
   - actualiza `last_sync_at`;
   - marca la entidad como `synced`.
7. Si el envío falla:
   - registra error;
   - incrementa intentos;
   - reprograma próximo intento;
   - continúa cuando es seguro.

## Batch

Cuando una inspección nueva y sus hallazgos están contiguos en cola, `SyncWorker` usa `pushBatch`.

La implementación Firestore usa `WriteBatch`, de modo que una inspección y sus hallazgos pueden publicarse atómicamente.

## Descarga

1. `RemoteSyncDataSource.fetchChanges()` consulta inspecciones modificadas desde cursor.
2. Consulta hallazgos asociados.
3. `RemoteSyncApplier` inserta o actualiza SQLite.
4. Guarda cursor de última sincronización.
5. Evita duplicados por `global_id`.

## Conflictos

Estrategia inicial:

- si `remote_version` coincide con la versión esperada, se aplica el cambio;
- si la versión remota es superior y existe cambio local pendiente, se marca `conflict`;
- no se sobrescribe silenciosamente;
- se conserva copia local;
- se conserva payload remoto en notas diagnósticas para resolución futura.

No se implementa todavía pantalla de resolución.

## Estados

- `offline`
- `syncing`
- `synced`
- `partialFailure`
- `conflict`
- `unavailable`

## Ejecución

No hay sincronización automática al arranque en este sprint.

Solo queda disponible el método manual:

```text
syncNow()
```
