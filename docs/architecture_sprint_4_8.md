# Sprint 4.8 - Arquitectura de rendimiento local

Estado: implementado para validación.

## Objetivo

Optimizar rendimiento local y escalabilidad operativa sin cambiar flujo visible, base operativa, sincronización funcional, PDF, fotos, mapas ni autenticación.

## Cambios arquitectónicos

- `PerformanceMonitor` mide operaciones locales con `Stopwatch` y registra solo metadatos seguros en `AppLogger`.
- `QueryPageConfig` centraliza tamaños de página de historial y detalles de dashboard.
- `SyncBatchConfig` centraliza tamaños internos de push, pull y aplicación local.
- SQLite sube a versión 4 solo para crear índices no destructivos.
- Historial carga progresivamente con cursor estable por `fecha_iso` + `global_id`.
- Detalle de hallazgos del dashboard carga progresivamente en páginas.
- `DashboardController` reutiliza resumen en memoria mientras la revisión local no cambia.
- `SyncWorker` procesa la cola local por páginas configuradas.
- Firestore pull usa cursor compuesto real con `startAfter(updated_at, global_id)` y límite por colección.

## Confirmaciones

- SQLite continúa siendo la única base operativa.
- Firestore continúa únicamente como intercambio remoto.
- Dashboard, historial y avance no consultan Firestore.
- No se agregó Firebase Storage.
- Fotografías, rutas locales, PDF, mapas y borradores siguen locales.
- No se implementaron tareas con la aplicación cerrada.
- No se modificó el diseño del PDF.

## Limitaciones

- El filtrado avanzado por semáforo/tipo en detalle de hallazgos sigue calculándose en dominio para no duplicar reglas ni persistir columnas normalizadas en este sprint.
- No se implementa cache persistente del dashboard; solo cache en memoria invalidada por revisión local.
