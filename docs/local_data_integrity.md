# Integridad de datos locales

Este documento describe las reglas de integridad y recuperación interna de LINERB V2.

## Principios

- No borrar datos automáticamente.
- Aislar y marcar datos inválidos.
- Conservar evidencia para diagnóstico.
- Mantener compatibilidad con V1.
- No mostrar aún información técnica en UI.

## Reglas de integridad

### Inspecciones

Una inspección es inválida si:

- no tiene `id`;
- tiene campos obligatorios vacíos;
- tiene `fecha_iso` no parseable;
- duplica otra inspección por campos visibles.

### Hallazgos

Un hallazgo es inválido si:

- no tiene `id`;
- no pertenece a borrador ni inspección;
- apunta a una inspección inexistente;
- tiene campos obligatorios corruptos;
- duplica otro hallazgo por contenido y dueño.

### Borrador

Un borrador es inválido si:

- no tiene `id`;
- no tiene usuario;
- no tiene tipo de línea;
- no tiene línea seleccionada;
- no tiene estado;
- no tiene `updated_at`.

## Tabla de issues

```text
integrity_issues
```

Campos:

- `id`
- `entity_type`
- `entity_id`
- `issue_type`
- `evidence`
- `detected_at`
- `resolution`

## Reparación automática

Automática:

- marcar `is_invalid = 1`;
- guardar `diagnostic_notes`;
- registrar evidencia en `integrity_issues`;
- registrar fecha de validación.

No automática:

- borrar registros;
- modificar datos de negocio;
- fusionar duplicados;
- reasignar hallazgos huérfanos;
- sobrescribir datos V1.

## Diagnóstico

El diagnóstico queda disponible por código para pruebas y futuros paneles internos.

No se expone todavía al usuario final.

## Rollback

El guardado completo usa transacción. Si falla la inserción de cualquier hallazgo:

- no queda inspección parcial;
- no quedan hallazgos parciales;
- el borrador no debe eliminarse porque el borrado ocurre después del commit exitoso.
