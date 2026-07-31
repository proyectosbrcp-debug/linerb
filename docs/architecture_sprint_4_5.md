# Arquitectura Sprint 4.5 / cierre 4.5.1

Sprint 4.5 define el motor automático de sincronización de LINERB V2. SQLite continúa siendo la única base operativa; Firestore se usa únicamente como mecanismo remoto de intercambio de datos estructurados.

## Componentes

- `AutomaticSyncCoordinator`: coordina disparadores, evita ciclos paralelos, expone estado operativo y administra timers.
- `SyncWorker`: procesa `sync_queue`, hace push y pull incremental, aplica reintentos y respeta permisos.
- `RemoteSyncDataSource`: contrato remoto.
- `FirestoreRemoteSyncDataSource`: implementación Firestore.
- `RemoteSyncApplier`: aplica cambios remotos en SQLite sin reencolar.
- `SyncQueueStorage`: cola persistente local.
- `SyncMetadataStorage`: metadatos locales de sincronización por entidad.
- `DeviceIdentityService`: identificador local estable no sensible.

## Brechas corregidas en 4.5.1

- Faltaba pull incremental verdadero con cursor compuesto.
- Existía un cursor único por fecha para todas las entidades.
- El cursor no distinguía `inspections` y `findings`.
- El data source de hallazgos escribía en subcolecciones, mientras las reglas y el modelo documentado usaban colección top-level.
- `SyncWorker` no consumía cursores compuestos desde el applier.
- La documentación de Firestore todavía mencionaba subcolección de hallazgos.
- La validación LWW no estaba caracterizada con suficientes escenarios.

## Estado corregido

- Push automático: `SyncWorker` procesa operaciones elegibles de `sync_queue`.
- Pull automático: `SyncWorker` consulta cambios remotos cuando existe `RemoteSyncApplier`.
- Pull incremental: usa cursor compuesto `updated_at + global_id`.
- Cursores independientes: `remote_sync_cursor_inspections` y `remote_sync_cursor_findings`.
- Prevención de paralelismo: `AutomaticSyncCoordinator` bloquea un segundo ciclo si otro está activo.
- Last Write Wins: el applier compara timestamps, tolerancia de clock skew y versiones.
- Aplicación remota: se inserta/actualiza SQLite sin crear nuevas operaciones en `sync_queue`.
- Dashboard, historial y avance siguen leyendo SQLite.
- Fotos, PDF, rutas locales, mapas y borradores quedan fuera del payload remoto.

## Disparadores automáticos

- apertura/restauración de sesión;
- login;
- finalización de inspección;
- recuperación de conectividad;
- timer periódico;
- sincronización manual controlada.

## Recursos

`AutomaticSyncCoordinator.stop()` cancela timers periódicos, timers de retry y debounce de conectividad. `dispose()` detiene el coordinador y cierra el stream.
