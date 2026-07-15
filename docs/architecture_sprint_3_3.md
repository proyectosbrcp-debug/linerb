# LINERB V2 - Sprint 3.3

## Objetivo

Sprint 3.3 mejora la utilidad operativa del dashboard mediante filtros combinables y pantallas de detalle, sin modificar las reglas de negocio del motor creado en Sprint 3.1.

## Componentes agregados

- `DashboardFilter`
  - Modelo tipado para representar filtros activos.
  - Soporta tipo de línea, semáforo, responsable y periodo.

- `DashboardPriorityDetailPage`
  - Muestra todas las líneas priorizadas.
  - Permite búsqueda por nombre.
  - Permite filtrar por tipo y semáforo.

- `DashboardFindingsDetailPage`
  - Muestra total filtrado de hallazgos.
  - Agrupa por categoría.
  - Lista línea, fecha, responsable y descripción.

## Cambios en el controlador

`DashboardController` ahora permite:

- `loadSummary(filter: ...)`
- `loadPriorityDetails(filter: ..., searchQuery: ...)`
- `loadFindingsDetail(filter: ...)`

Los filtros se aplican en el controlador, no en los widgets. La UI no recalcula cobertura, semáforo, agrupaciones ni exclusión de inválidos.

## Flujo de datos

```text
DashboardPage
  -> DashboardController
    -> DashboardRepository
      -> SQLite
```

Para hallazgos, `SqliteDashboardRepository` consulta `hallazgos` con `INNER JOIN inspections`, excluyendo registros inválidos de ambas tablas.

## Compatibilidad

- No se agregaron paquetes.
- No se modificó Firebase.
- No se modificó el flujo de inspección.
- Las pantallas usan scroll y controles verticales para mantener compatibilidad con teléfonos pequeños.

## Reglas preservadas

Las reglas del semáforo siguen centralizadas en `LineSemaforoRule`.

La normalización de líneas sigue centralizada en `LineIdentityNormalizer`.

La exclusión de registros inválidos sigue ocurriendo desde la fuente SQLite y el repositorio del dashboard.
