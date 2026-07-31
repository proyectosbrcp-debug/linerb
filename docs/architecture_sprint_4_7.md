# Sprint 4.7 - Robustez, observabilidad y experiencia de sincronización

## Auditoría inicial

Componentes existentes revisados:

- `SyncWorker`: procesaba `sync_queue` con push remoto, batching de inspección + hallazgos, prevención de borrado ante fallo y reintento fijo.
- `SyncQueueStorage` / `LocalSyncQueueStorage`: cola local SQLite con intentos, `next_attempt_at`, `last_error` y conflictos.
- `SyncMetadataStorage` / `LocalSyncMetadataStorage`: metadatos de sincronización por inspección/hallazgo.
- `RemoteSyncDataSource` / `FirestoreRemoteSyncDataSource`: push y fetch remoto desde Firestore.
- `RemoteSyncApplier`: aplicación local de cambios remotos sin reencolar datos y con cursor en `migration_metadata`.
- `AuthController` y `PermissionService`: sesión/perfil/roles.
- Dashboard, historial y avance: continúan consultando repositorios locales/SQLite.

Brechas encontradas antes de Sprint 4.7:

- No existía `AutomaticSyncCoordinator`.
- `SyncWorker` no integraba todavía `pull` incremental dentro del ciclo operativo.
- No había modelo central de estado ni stream observable.
- No había indicador visual ni detalle de sincronización.
- El backoff era fijo.

Por esta brecha de prerrequisito, el Sprint 4.7 no debe declararse cerrado como cumplimiento total del enunciado original. Se corrigió lo indispensable para que el estado visible represente el estado real sin crear una segunda arquitectura.

## Arquitectura implementada

`AutomaticSyncCoordinator` es la fuente única de estado operativo de sincronización.

Flujo:

1. UI/arranque/eventos llaman al coordinador.
2. El coordinador consulta sesión, perfil, permisos y cola local.
3. El coordinador publica `SyncStatusSnapshot`.
4. El coordinador ejecuta `SyncWorker` si las condiciones lo permiten.
5. `SyncWorker` usa `RemoteSyncDataSource` para push y `RemoteSyncApplier` para pull incremental.
6. El resultado vuelve al coordinador, que recalcula pendientes/fallos/conflictos.
7. La UI consume solo el stream del coordinador.

## Límites conservados

- SQLite sigue siendo la única base operativa.
- Firestore sigue siendo mecanismo remoto de intercambio.
- La UI no consulta Firestore, `sync_queue`, FirebaseAuth ni conectividad directamente.
- No se agregó Firebase Storage.
- No se sincronizan fotografías, rutas locales, PDF, mapas ni borradores.
- No se implementó WorkManager, push notifications ni tareas con la app cerrada.
- No se modificó el diseño del informe PDF Sprint 4.6.

## Recursos gestionados

El coordinador controla:

- ciclo en curso para evitar sincronización concurrente;
- timer periódico;
- timer de retry;
- debounce de conectividad;
- stream broadcast de estado.

`stop()` cancela timers y publica `stopped`. `dispose()` cierra el stream.
