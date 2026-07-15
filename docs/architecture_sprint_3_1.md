# Arquitectura Sprint 3.1

Sprint 3.1 crea el motor de indicadores del dashboard sin agregar pantalla visual, gráficos ni navegación.

## Componentes creados

```text
lib/core/domain/
  line_identity.dart
  line_semaforo.dart

lib/models/
  dashboard_models.dart

lib/repositories/
  dashboard_repository.dart

lib/controllers/
  dashboard_controller.dart
```

## Flujo de datos

```text
DashboardController
  -> DashboardRepository
    -> SQLite inspections / hallazgos
    -> CatalogRepository
      -> catálogos actuales
```

## Fuente principal

Las inspecciones y hallazgos salen de SQLite:

- `inspections`
- `hallazgos`

Solo se consideran registros con:

```text
is_invalid = 0
```

Los registros inválidos se cuentan por separado en `invalidRecordsExcluded`.

## Catálogo

El total de líneas se calcula con los catálogos actuales:

- troncales/subtroncales desde `CatalogData.troncalesJson`;
- ramales desde `CatalogData.ramalesJson`.

No se modificó Firebase ni el catálogo remoto.

## Semáforo compartido

La regla vive en:

```text
lib/core/domain/line_semaforo.dart
```

La usan:

- `ProgressController`
- `DashboardController`

Reglas:

- verde: 0 a 15 días;
- amarillo: más de 15 días y hasta 60 días;
- rojo: más de 60 días o nunca inspeccionada.

## Normalización de líneas

La normalización vive en:

```text
lib/core/domain/line_identity.dart
```

Reglas:

- trim inicial/final;
- colapsar espacios repetidos;
- normalizar espacios alrededor de `/`;
- comparar en mayúsculas;
- distinguir:
  - `ramal`;
  - `troncal`;
  - `subtroncal`;
  - `desconocida`;
- evitar duplicados por variantes de escritura.

## Reloj inyectable

`DashboardController` recibe:

```text
DateTime Function() clock
```

Esto permite pruebas deterministas para semáforos y periodos.

## Sin cambios visibles

No se agregó UI, pantalla, gráfico, navegación ni funcionalidades visibles.
