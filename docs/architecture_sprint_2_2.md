# Arquitectura Sprint 2.2

Sprint 2.2 crea una base interna para LINERB V2 sin cambiar la experiencia visible de LINERB V1.

## Alcance aplicado

- Se crean contratos de repositorio para catálogos, inspecciones y borradores.
- Se crean implementaciones temporales que siguen usando `DatosApp`, `SharedPreferences`, cache local, assets internos y las URLs actuales de catálogos.
- Se crean controladores básicos sin `Widget`, `BuildContext`, `Navigator`, `ScaffoldMessenger` ni código visual.
- No se migra la persistencia.
- No se modifica Firebase ni las URLs actuales.
- No se cambian pantallas, textos, estilos ni navegación.

## Capas creadas

```text
lib/
  controllers/
    history_controller.dart
    inspection_registration_controller.dart
    progress_controller.dart
    selection_line_controller.dart
  repositories/
    catalog_repository.dart
    draft_repository.dart
    inspection_repository.dart
  storage/
    shared_preferences_storage.dart
```

## Repositorios

### CatalogRepository

Responsabilidad:

- Cargar catálogos de troncales y ramales.
- Mantener el orden actual de fuentes:
  1. Firebase actual.
  2. Cache local en `SharedPreferences`.
  3. JSON interno en assets.

Implementación temporal:

- `CurrentCatalogRepository`
- Usa las mismas URLs declaradas en `core/constants/catalog_urls.dart`.
- Conserva las mismas claves de cache:
  - `json_troncales_cache`
  - `json_ramales_cache`

### InspectionRepository

Responsabilidad:

- Agregar inspecciones a la memoria actual.
- Consultar inspecciones en memoria para avance.
- Cargar y guardar historial en el almacenamiento actual.

Implementación temporal:

- `CurrentInspectionRepository`
- Usa `DatosApp.inspecciones` para memoria en ejecución.
- Usa `SharedPreferences` con la clave actual:
  - `historial_inspecciones`

### DraftRepository

Responsabilidad:

- Guardar borrador local.
- Cargar borrador local de la línea seleccionada.
- Borrar borrador local después de guardar una inspección.

Implementación temporal:

- `CurrentDraftRepository`
- Usa `SharedPreferences` con las claves actuales:
  - `borrador_usuario`
  - `borrador_tipoLinea`
  - `borrador_seleccionLinea`
  - `borrador_responsable`
  - `borrador_puntoReferencia`
  - `borrador_estadoLinea`
  - `borrador_hallazgos`

## Controladores

### SelectionLineController

Responsabilidad:

- Coordinar carga de catálogos mediante `CatalogRepository`.
- Exponer la operación `todasLasLineas` para construir el listado usado por avance.

No contiene código visual ni navegación.

### InspectionRegistrationController

Responsabilidad:

- Coordinar operaciones de borrador mediante `DraftRepository`.
- Resolver el detalle técnico actual de hallazgo según selección.

No contiene código visual ni navegación.

### HistoryController

Responsabilidad:

- Cargar historial mediante `InspectionRepository`.
- Exponer la lista de inspecciones cargadas.

No contiene código visual ni navegación.

### ProgressController

Responsabilidad:

- Consultar última inspección por línea mediante `InspectionRepository`.
- Mantener el cálculo actual del semáforo de avance.

No contiene código visual ni navegación.

## Integración mínima realizada

- Selección de línea delega la carga de catálogos y el armado de líneas al controlador/repositorio.
- Registro de inspección delega guardado, carga y borrado de borrador al controlador/repositorio.
- Historial delega la carga de datos al controlador/repositorio.
- Avance delega la consulta de última inspección y el semáforo al controlador/repositorio.
- Resumen delega el guardado de inspección e historial al repositorio y el borrado de borrador al controlador.

## Garantía de compatibilidad V1

La persistencia física sigue siendo la misma:

- `SharedPreferences` no fue migrado.
- `DatosApp.inspecciones` sigue siendo la memoria en ejecución.
- Las claves existentes se conservan.
- Las rutas de navegación no cambian.
- La UI, textos y estilos no cambian.
