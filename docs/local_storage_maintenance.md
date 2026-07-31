# Sprint 4.8 - Mantenimiento de almacenamiento local

## Política implementada

- No se ejecuta `VACUUM` automáticamente.
- No se borran datos automáticamente.
- No se eliminan fotografías finalizadas.
- No se eliminan PDFs existentes.
- No se sincronizan mapas ni rutas locales.
- No se crean miniaturas persistentes.

## Diagnóstico disponible

`LocalDiagnosticService` ahora expone:

- cantidad de inspecciones;
- cantidad de hallazgos;
- cantidad de issues de integridad;
- estado de migración;
- estado runtime ready/degraded;
- último error de inicialización;
- fecha de última validación;
- operaciones pendientes de sync;
- tombstones;
- tamaño del archivo SQLite cuando está disponible.

No se expone la ruta completa del archivo a usuarios normales.

## Recomendaciones futuras

- Evaluar `PRAGMA optimize` después de ciclos de escritura grandes, solo cuando la app esté inactiva.
- Mantener `VACUUM` como acción manual o mantenimiento condicionado, nunca en cada arranque.
- Considerar limpieza explícita de temporales de mapa únicamente si se identifica acumulación real.
