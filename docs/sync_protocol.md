# Protocolo local de sincronización

## Fuente operativa

SQLite es la única base operativa. La UI, historial, avance y dashboard leen datos locales. Firestore solo intercambia datos estructurados remotos.

## Entidades sincronizadas

- `inspection`
- `finding`

No se sincronizan fotografías, rutas locales, PDF, mapas ni borradores.

## Cola persistente

La tabla `sync_queue` guarda:

- entidad;
- ID local/global;
- operación;
- payload estructurado;
- intentos;
- próximo reintento;
- último error resumido;
- marca de conflicto.

## Operaciones

- `create`
- `update`
- `delete`

## Compactación

- `create + update` => `create` con payload más reciente.
- `update + update` => un solo `update` con payload más reciente.
- `create + delete` => se elimina la operación pendiente.
- `update + delete` => `delete`.
- operaciones en conflicto no se compactan.

## Pull incremental

El pull no descarga toda la colección después de tener cursor.

Cada colección usa un cursor independiente:

- `remote_sync_cursor_inspections`
- `remote_sync_cursor_findings`

Cada cursor contiene:

- `updated_at`
- `global_id`

La siguiente consulta descarga únicamente documentos donde:

```text
updated_at > cursor.updated_at
```

o:

```text
updated_at == cursor.updated_at
and global_id > cursor.global_id
```

Esto permite avance determinista cuando varios documentos comparten el mismo timestamp.

## Last Write Wins

Al aplicar datos remotos sobre una fila local pendiente:

1. Si la diferencia entre timestamps supera la tolerancia de clock skew, gana el timestamp más reciente.
2. Si la diferencia está dentro de la tolerancia, decide `remote_version`.
3. Si versiones empatan, decide `global_id` de forma determinista.
4. Si no hay datos suficientes, se marca conflicto sin borrar evidencia.

## Datos excluidos

Los mappers remotos rechazan campos relacionados con:

- fotos;
- imágenes;
- Base64;
- PDF;
- archivos;
- rutas/path/ruta;
- draft/borrador;
- mapas.

## Logging

Se registra únicamente información técnica resumida: trigger, inicio, fin, duración, enviados, descargados, aplicados, pendientes y categoría de error. No se registran payloads completos, tokens, API keys, rutas, PDF, fotos ni bytes.
