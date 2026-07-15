# Arquitectura Sprint 2.4

Sprint 2.4 introduce una base de datos local versionada para LINERB V2 y prepara una migración segura desde `SharedPreferences`, sin cambiar la experiencia visible de LINERB V1.

## Tecnología seleccionada

Se seleccionó `sqflite`.

Alternativas evaluadas:

- `sqflite`
- `drift`

Justificación:

- `sqflite` tiene menor impacto sobre la arquitectura actual.
- No requiere generación de código ni `build_runner`.
- Permite migraciones versionadas con `onCreate` y `onUpgrade`.
- Es suficiente para el modelo actual de inspecciones, hallazgos, borrador y metadatos.
- Mantiene simple la transición desde los contratos `InspectionStorage` y `DraftStorage`.

`drift` queda como alternativa futura si LINERB necesita consultas reactivas, relaciones más complejas o validación tipada más fuerte a nivel de query.

## Dependencias agregadas

Dependencias de producción:

- `sqflite`
- `path`

Dependencia de desarrollo/pruebas:

- `sqflite_common_ffi`

`sqflite_common_ffi` se usa para ejecutar pruebas de SQLite en memoria sin depender del plugin nativo móvil.

## Esquema de base de datos

Archivo principal:

```text
lib/storage/local/linerb_database.dart
```

Base:

```text
linerb_v2.db
version: 1
```

### inspections

Guarda inspecciones históricas.

```sql
id TEXT PRIMARY KEY
linea TEXT NOT NULL
tipo_linea TEXT NOT NULL
responsable TEXT NOT NULL
fecha_iso TEXT NOT NULL
estado_linea TEXT NOT NULL
punto_referencia TEXT NOT NULL
observaciones TEXT NOT NULL
source TEXT NOT NULL
source_key TEXT UNIQUE
created_order INTEGER NOT NULL
```

### hallazgos

Guarda hallazgos asociados a borrador y queda preparada para asociarlos a inspecciones.

```sql
id TEXT PRIMARY KEY
inspection_id TEXT
draft_id TEXT
tipo TEXT NOT NULL
detalle TEXT NOT NULL
latitud TEXT NOT NULL
longitud TEXT NOT NULL
descripcion TEXT NOT NULL
foto1_path TEXT
foto2_path TEXT
created_order INTEGER NOT NULL
```

### draft

Guarda el borrador actual.

```sql
id TEXT PRIMARY KEY
usuario TEXT NOT NULL
tipo_linea TEXT NOT NULL
seleccion_linea TEXT NOT NULL
responsable TEXT NOT NULL
punto_referencia TEXT NOT NULL
estado_linea TEXT NOT NULL
updated_at TEXT NOT NULL
```

### migration_metadata

Registra estado de migraciones.

```sql
key TEXT PRIMARY KEY
value TEXT NOT NULL
updated_at TEXT NOT NULL
```

## IDs estables

Archivo:

```text
lib/core/utils/stable_id.dart
```

Los datos V1 no tienen IDs. Durante migración se generan IDs determinísticos:

- inspecciones V1: `v1_inspection_<hash estable del JSON original>`
- inspecciones nuevas: `db_inspection_<hash estable de campos principales>`
- hallazgos: `hallazgo_<hash estable de borrador/inspección + índice + contenido>`

Esto permite que la migración sea idempotente y que ejecutar el proceso varias veces no duplique registros.

## Implementaciones nuevas

```text
lib/storage/local/local_database_storage.dart
```

Implementa:

- `InspectionStorage`
- `DraftStorage`
- `MigrationTarget`

Responsabilidades:

- guardar y leer inspecciones desde SQLite;
- guardar, leer y borrar borrador desde SQLite;
- persistir hallazgos asociados al borrador;
- registrar metadatos de migración;
- insertar inspecciones V1 con `source_key` único para evitar duplicados.

## Fallback temporal

Archivos:

```text
lib/storage/fallback_inspection_storage.dart
lib/storage/fallback_draft_storage.dart
```

Estrategia:

```text
Si migration_metadata[v1_shared_preferences] == completed:
  usar SQLite como fuente principal
Si no:
  usar SharedPreferencesStorage como fuente V1
```

Para avance, se conserva la memoria de ejecución compatible con `DatosApp`, manteniendo el comportamiento visible actual.

## Catálogos

El cache de catálogos no se migró en este sprint.

`CatalogCacheStorage` continúa usando:

```text
SharedPreferencesStorage
```

Claves conservadas:

- `json_troncales_cache`
- `json_ramales_cache`

## Inyección de dependencias

Archivo:

```text
lib/core/di/app_dependencies.dart
```

Flujo:

```text
Pantallas
  -> Controllers
    -> Repositories
      -> Fallback storage
        -> SQLite si migración completa
        -> SharedPreferencesStorage si migración pendiente
```

No se agregó paquete de inyección de dependencias.

## Garantías del sprint

- No se cambió UI.
- No se cambió navegación.
- No se cambió Firebase.
- No se eliminaron claves V1.
- No se migró cache de catálogos.
- `SharedPreferencesStorage` sigue existiendo.
- La migración es idempotente.
- Los controllers no importan Flutter UI.
