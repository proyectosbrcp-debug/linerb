# Modelo de datos Firestore

Firestore es un mecanismo remoto de intercambio. No es fuente operativa para la UI.

## Colección `inspections`

Ruta:

```text
inspections/{global_id}
```

Campos permitidos:

- `global_id`
- `fecha`
- `responsable`
- `usuario`
- `tipo_linea`
- `linea`
- `subtroncal`
- `punto_referencia`
- `estado_linea`
- `observacion_general`
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`
- `device_id`
- `local_version`
- `remote_version`
- `sync_status`
- `deleted_at`

## Colección `findings`

Ruta:

```text
findings/{global_id}
```

Campos permitidos:

- `global_id`
- `inspection_global_id`
- `categoria`
- `subcategoria`
- `descripcion`
- `latitud`
- `longitud`
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`
- `device_id`
- `local_version`
- `remote_version`
- `deleted_at`

## Regla de consistencia

LINERB no mezcla subcolecciones y colecciones top-level para la misma entidad. Los hallazgos se escriben y leen desde `findings/{global_id}`.

## Cursores

El pull incremental usa cursores separados por colección:

- inspections: `updated_at + global_id`
- findings: `updated_at + global_id`

## Campos excluidos

No se permite enviar a Firestore:

- fotografías;
- bytes;
- Base64;
- rutas locales;
- nombres de archivo locales;
- PDF;
- rutas del PDF;
- mapa o imagen de mapa;
- borrador;
- diagnósticos internos sensibles.

## Fuente del dashboard, historial y avance

Dashboard, historial y avance no consultan Firestore. Sus datos salen de SQLite.
