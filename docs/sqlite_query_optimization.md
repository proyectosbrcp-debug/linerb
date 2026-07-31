# Sprint 4.8 - Optimización de consultas SQLite

## Índices agregados en versión 4

| Índice | Tabla | Justificación |
|---|---|---|
| `idx_inspections_history_cursor` | `inspections(fecha_iso DESC, global_id DESC)` | Paginación de historial por cursor estable |
| `idx_inspections_valid_fecha` | `inspections(is_invalid, fecha_iso DESC)` | Dashboard e historial excluyen inválidos y ordenan por fecha |
| `idx_inspections_updated_at_global_id` | `inspections(updated_at, global_id)` | Sync incremental y revisión local |
| `idx_inspections_responsable` | `inspections(responsable)` | Filtros y agrupaciones por responsable |
| `idx_inspections_tipo_linea` | `inspections(tipo_linea)` | Filtros por tipo de línea |
| `idx_inspections_deleted_at` | `inspections(deleted_at)` | Exclusión de tombstones |
| `idx_hallazgos_updated_at_global_id` | `hallazgos(updated_at, global_id)` | Sync incremental |
| `idx_hallazgos_categoria` | `hallazgos(tipo)` | Agrupación por categoría |
| `idx_hallazgos_valid_inspection` | `hallazgos(is_invalid, inspection_id)` | Join de hallazgos válidos por inspección |
| `idx_sync_queue_due` | `sync_queue(next_attempt_at, created_at)` | Cola elegible por reintento y orden estable |
| `idx_sync_queue_created_at` | `sync_queue(created_at)` | Procesamiento FIFO por lotes |
| `idx_sync_queue_attempts` | `sync_queue(attempts)` | Diagnóstico de operaciones atascadas |

Todos los índices son no destructivos y se crean con `IF NOT EXISTS`.

## Consultas optimizadas

- Historial: `ORDER BY fecha_iso DESC, global_id DESC LIMIT pageSize + 1`.
- Hallazgos dashboard: join filtrado por válidos/no eliminados, ordenado por fecha e ID.
- Categorías de hallazgos: `GROUP BY` en SQLite para el caso no filtrado.
- Conteo de hallazgos válidos: `COUNT` en SQLite.
- Sync queue: página elegible por `next_attempt_at` y `created_at`.

## Consultas que siguen en dominio

- Semáforo y normalización de líneas permanecen en dominio para reutilizar `LineSemaforoRule` y `LineIdentityNormalizer`.
- Filtros que dependen de semáforo/tipo normalizado no se duplican en SQL en este sprint.
