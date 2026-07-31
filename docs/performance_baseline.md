# Sprint 4.8 - Línea base de rendimiento

## Línea base inicial

Antes de optimizar se auditó el código existente. No había instrumentación local de tiempos por operación, por lo que la línea base inicial queda caracterizada por comportamiento algorítmico y consultas observadas:

| Área | Línea base inicial | Riesgo |
|---|---|---|
| Arranque | SQLite y migración se ejecutaban sin medición centralizada | No había duración registrada por etapa |
| Historial | `cargarHistorial()` cargaba todo el historial | Memoria y tiempo crecían linealmente |
| Dashboard | Cargaba inspecciones y hallazgos válidos completos y agrupaba en Dart | Costo alto con miles de registros |
| Detalle de hallazgos | Renderizaba todos los hallazgos recibidos | Lista grande en memoria |
| Sync queue | `pendingOperations()` cargaba toda la cola | Cola de 1.000+ operaciones podía crecer en memoria |
| Pull incremental | Firestore traía cambios sin límite local explícito | Lotes remotos grandes en un solo ciclo |
| Fotos | Se mantienen como rutas locales, bytes solo al usar PDF | Sin bytes en SQLite ni sync |
| PDF | Sprint 4.6 cerrado; no se modificó diseño ni layout | Solo se mantiene fuera de cambios |
| Listeners/timers | `AutomaticSyncCoordinator` conserva exclusión mutua y ciclo adicional máximo | Sin tarea con app cerrada |

## Medición final agregada

`PerformanceMonitor` permite medir:

- nombre de operación;
- fecha de inicio;
- duración;
- cantidad de registros;
- resultado;
- categoría de fallo.

No registra payloads, contraseñas, tokens, fotos, rutas completas, PDF ni descripciones completas.

Operaciones instrumentadas:

- `app.open_database`;
- `app.v1_migration`;
- `history.load_page`;
- `dashboard.load_valid_inspections`;
- `dashboard.load_findings_page`;
- `sync_queue.load_pending_page`.

## Resultado de pruebas de rendimiento locales

La prueba `test/performance_sprint_4_8_test.dart` valida:

- índices críticos creados;
- historial paginado;
- detalle de hallazgos paginado;
- cache del dashboard por revisión;
- cola de 1.000 operaciones procesada por páginas.

Resultado local previo a validación completa: 5/5 pruebas aprobadas.
