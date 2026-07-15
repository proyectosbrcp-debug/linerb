# Migración de datos V1 a base local

Este documento describe la migración preparada en Sprint 2.4 desde `SharedPreferences` hacia SQLite.

## Estado

La migración está implementada como servicio, pero no elimina ni modifica los datos V1.

Archivo:

```text
lib/storage/migration/v1_data_migration_service.dart
```

## Claves V1 leídas

### Historial

- `historial_inspecciones`

### Borrador

- `borrador_usuario`
- `borrador_tipoLinea`
- `borrador_seleccionLinea`
- `borrador_responsable`
- `borrador_puntoReferencia`
- `borrador_estadoLinea`
- `borrador_hallazgos`

Ninguna de estas claves se borra durante la migración.

## Datos migrados

### Inspecciones

Cada string JSON de `historial_inspecciones` se intenta convertir a una fila de `inspections`.

Campos esperados:

- `linea`
- `tipoLinea`
- `responsable`
- `fecha`
- `estadoLinea`
- `puntoReferencia`
- `observaciones`

Si un registro está incompleto o corrupto, se omite y queda reportado.

### Borrador

Si existe `borrador_seleccionLinea`, se migra el borrador actual a la tabla `draft`.

Los hallazgos del borrador se migran a la tabla `hallazgos`.

Si un hallazgo del borrador tiene JSON corrupto, se omite ese hallazgo y se continúa con el resto del borrador.

## Idempotencia

La migración usa:

- IDs estables derivados del contenido V1.
- `source_key` único por inspección migrada.
- metadata `migration_metadata[v1_shared_preferences]`.

Si se ejecuta de nuevo después de completarse:

- no duplica inspecciones;
- no duplica borrador;
- retorna reporte `alreadyCompleted`.

## Reporte de migración

El servicio retorna `MigrationReport` con:

- `alreadyCompleted`
- `completed`
- `migrated`
- `skipped`
- `failed`
- `messages`

Interpretación:

- `migrated`: registros insertados o borrador migrado.
- `skipped`: datos inexistentes, duplicados, incompletos o corruptos que no bloquean.
- `failed`: error de escritura o fallo operativo que impide marcar la migración como completa.

## Fallback operativo

Mientras la migración no esté marcada como completa:

```text
LINERB usa SharedPreferencesStorage para historial y borrador.
```

Después de una migración completa:

```text
LINERB usa SQLite para historial y borrador.
```

El cache de catálogos permanece en `SharedPreferences`.

## Conservación de datos V1

Sprint 2.4 no elimina claves antiguas.

La limpieza futura de claves V1 debe ser un sprint separado, posterior a validación en campo y con respaldo confirmado.
