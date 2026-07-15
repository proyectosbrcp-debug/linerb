# Arquitectura Sprint 2.3

Sprint 2.3 fortalece la persistencia de LINERB V2 sin migrar todavía a una base de datos local.

## Alcance aplicado

- No se migró a SQLite, Drift, Hive, Isar ni otra base de datos.
- No se cambiaron claves de `SharedPreferences`.
- No se cambió la serialización existente salvo para encapsularla dentro de storage.
- No se modificó Firebase ni el catálogo remoto.
- No se cambiaron pantallas, textos, estilos ni navegación.
- Los controllers siguen sin depender de Flutter UI.

## Contratos de almacenamiento

```text
lib/storage/
  inspection_storage.dart
  draft_storage.dart
  catalog_cache_storage.dart
```

### InspectionStorage

Responsable de abstraer:

- inspecciones en memoria de ejecución;
- historial persistido actual;
- consulta de última inspección por línea.

Métodos principales:

- `obtenerInspeccionesMemoria`
- `agregarInspeccionMemoria`
- `ultimaInspeccionMemoria`
- `cargarHistorial`
- `agregarInspeccionHistorial`

### DraftStorage

Responsable de abstraer:

- guardado de borrador;
- carga de borrador por línea;
- borrado de borrador.

Métodos principales:

- `guardarBorrador`
- `cargarBorrador`
- `borrarBorrador`

### CatalogCacheStorage

Responsable de abstraer:

- cache local de catálogos;
- lectura de cache de troncales/ramales;
- escritura de cache remoto descargado.

Métodos principales:

- `cargarCatalogosCache`
- `guardarCatalogosCache`

## Errores tipados

```text
lib/storage/storage_exceptions.dart
```

Se definieron excepciones tipadas para separar fallos de persistencia:

- `StorageNotFoundException`: el dato no existe.
- `StorageCorruptDataException`: el dato existe pero el JSON o estructura no es válida.
- `StorageReadException`: error inesperado de lectura.
- `StorageWriteException`: error inesperado de escritura.

## Implementación actual

```text
SharedPreferencesStorage
  implements InspectionStorage,
             DraftStorage,
             CatalogCacheStorage
```

`SharedPreferencesStorage` conserva las claves actuales:

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

### Catálogo/cache

- `json_troncales_cache`
- `json_ramales_cache`

## Repositorios

Los repositorios ahora dependen de interfaces de storage:

```text
CurrentInspectionRepository -> InspectionStorage
CurrentDraftRepository      -> DraftStorage
CurrentCatalogRepository    -> CatalogCacheStorage
```

Esto permite sustituir `SharedPreferencesStorage` por una base local futura sin cambiar controllers ni pantallas.

## Inyección de dependencias manual

```text
lib/core/di/app_dependencies.dart
```

`AppDependencies` concentra las instancias mínimas:

- `SharedPreferencesStorage`
- `CurrentInspectionRepository`
- `CurrentDraftRepository`
- `CurrentCatalogRepository`
- factories de controllers

No se agregó ningún paquete externo de inyección de dependencias.

## Flujo resultante

```text
Pantallas
  -> Controllers
    -> Repositories
      -> Storage contracts
        -> SharedPreferencesStorage
          -> SharedPreferences / DatosApp
```

## Compatibilidad V1

Los repositorios conservan el comportamiento esperado:

- borrador inexistente sigue resolviendo como `null`;
- historial inexistente sigue resolviendo como lista vacía;
- cache inexistente de catálogo sigue cayendo a assets internos;
- JSON corrupto ahora queda distinguido por excepción tipada;
- errores de escritura ahora quedan distinguibles por excepción tipada.

## Pruebas agregadas

```text
test/storage_repositories_test.dart
```

Cubre:

- repositorio de borrador;
- repositorio de inspecciones;
- dato inexistente;
- JSON corrupto usando el formato actual;
- error simulado de escritura.
