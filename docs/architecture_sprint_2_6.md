# Arquitectura Sprint 2.6

Sprint 2.6 consolida la base SQLite local con validación de integridad, diagnóstico interno y reparación segura sin cambiar la experiencia visible.

## Base de datos

La base local sube a:

```text
linerb_v2.db
version: 2
```

Archivo:

```text
lib/storage/local/linerb_database.dart
```

## Restricciones e índices agregados

Restricciones existentes/conservadas:

- `inspections.id` como `PRIMARY KEY`.
- `hallazgos.id` como `PRIMARY KEY`.
- `migration_metadata.key` como `PRIMARY KEY`.
- `inspections.source_key` como `UNIQUE`.
- `hallazgos.inspection_id` con `FOREIGN KEY` hacia `inspections.id`.

Columnas nuevas:

- `inspections.is_invalid`
- `inspections.diagnostic_notes`
- `hallazgos.is_invalid`
- `hallazgos.diagnostic_notes`
- `draft.is_invalid`
- `draft.diagnostic_notes`

Tabla nueva:

```text
integrity_issues
```

Índices nuevos:

- `idx_inspections_fecha_iso`
- `idx_inspections_invalid`
- `idx_hallazgos_draft_id`
- `idx_hallazgos_inspection_id`
- `idx_hallazgos_invalid`
- `idx_migration_metadata_value`
- `idx_migration_metadata_updated_at`
- `idx_integrity_issues_type`
- `idx_integrity_issues_entity`

## Validación de integridad

Archivo:

```text
lib/storage/integrity/local_data_integrity_service.dart
```

Detecta:

- inspecciones sin ID;
- inspecciones con campos obligatorios vacíos;
- fechas inválidas;
- inspecciones duplicadas por campos visibles;
- hallazgos sin ID;
- hallazgos sin dueño;
- hallazgos con `inspection_id` inexistente;
- hallazgos duplicados por contenido;
- borradores incompletos.

## Diagnóstico local

Archivo:

```text
lib/storage/diagnostics/local_diagnostic_service.dart
```

Entrega internamente:

- número de inspecciones;
- número de hallazgos;
- número de issues de integridad;
- estado de migración;
- último error de inicialización;
- estado `ready/degraded`;
- fecha de última validación.

No se muestra en UI.

## Reparación segura

Sprint 2.6 no borra datos automáticamente.

Las reparaciones automáticas son:

- registrar evidencia en `integrity_issues`;
- marcar registros inválidos con `is_invalid = 1`;
- guardar causa en `diagnostic_notes`;
- registrar `last_integrity_validation` en `migration_metadata`.

Requieren intervención futura:

- fusionar duplicados;
- corregir IDs faltantes;
- reasignar hallazgos huérfanos;
- eliminar datos corruptos;
- resolver conflictos de negocio.

## Transacciones

El guardado de inspección finalizada y hallazgos queda transaccional:

```text
insert inspection
insert hallazgos
commit
```

Si falla un hallazgo, SQLite hace rollback y no queda una inspección parcial.

El borrador se borra después de un guardado exitoso, manteniendo la protección introducida en Sprint 2.5.

## Experiencia visible

No se modificaron:

- pantallas;
- textos;
- estilos;
- navegación;
- flujo de inspección;
- Firebase;
- catálogo remoto.
