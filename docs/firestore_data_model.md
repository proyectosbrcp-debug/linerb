# Modelo de datos Firestore

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

## Subcolección `findings`

Ruta:

```text
inspections/{global_id}/findings/{finding_global_id}
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

## Campos excluidos

No se permite enviar a Firestore:

- fotografía 1;
- fotografía 2;
- bytes;
- Base64;
- rutas locales;
- nombres de archivo locales;
- PDF;
- rutas del PDF;
- borrador;
- diagnósticos internos no necesarios.

## Fuente del dashboard

El dashboard no consulta Firestore. Sus cálculos siguen alimentándose desde SQLite.
