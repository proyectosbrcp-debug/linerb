# Sprint 4.8 - Estrategia de lotes de sincronización

## Constantes internas

Archivo: `lib/core/constants/sync_batch_config.dart`

| Constante | Valor | Uso |
|---|---:|---|
| `pushBatchSize` | 100 | Página de cola local elegible por ciclo |
| `pullInspectionsLimit` | 250 | Límite de lectura remota de inspecciones |
| `pullFindingsLimit` | 250 | Límite de lectura remota de hallazgos |
| `localApplyBatchSize` | 250 | Reserva para aplicación local por lote |

## Push

`SyncWorker` ya no carga toda la cola como fuente primaria de procesamiento. Consulta páginas elegibles con:

- `next_attempt_at IS NULL OR next_attempt_at <= now`;
- orden `created_at ASC`;
- límite `SyncBatchConfig.pushBatchSize`.

Se conserva:

- idempotencia;
- compactación de cola;
- conflictos;
- viewer sin push;
- reintentos;
- dependencias inspección/hallazgo;
- partial success.

## Pull

Firestore usa:

- colección `inspections`;
- colección `findings`;
- `orderBy(updated_at)`;
- `orderBy(global_id)`;
- `startAfter(updated_at, global_id)` cuando hay cursor;
- límite por colección.

Esto conserva el cursor compuesto del Sprint 4.5.1 y evita cargar cambios remotos ilimitados en un solo ciclo.

## Pruebas

`test/performance_sprint_4_8_test.dart` valida una cola de 1.000 operaciones procesada por páginas configuradas.
