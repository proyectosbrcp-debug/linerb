# LINERB V2 - Sprint 3.2

## Objetivo

Sprint 3.2 incorpora una pantalla visual de dashboard que consume exclusivamente el motor de indicadores creado en Sprint 3.1.

No se modificaron fórmulas, reglas de negocio, Firebase, catálogos remotos, flujo de inspección ni persistencia.

## Componentes creados

- `lib/pages/dashboard/dashboard_page.dart`
  - `DashboardPage`: pantalla visual del dashboard.
  - `_MetricCard`: tarjeta reutilizable para indicadores numéricos.
  - `_SemaforoCard`: tarjeta reutilizable para estado verde, amarillo y rojo.
  - `_PriorityRow`: fila reutilizable para líneas priorizadas.

## Integración

`DashboardPage` obtiene su `DashboardController` desde `AppDependencies.dashboardController()`.

La pantalla principal agrega un acceso nuevo hacia `DashboardPage` sin eliminar ni reemplazar accesos existentes:

- iniciar inspección;
- historial;
- avance;
- dashboard.

## Estados visuales

La pantalla maneja cuatro estados:

- cargando;
- sin datos;
- error genérico para usuario;
- datos disponibles.

Los errores se registran internamente con `AppLogger.warning` y no se exponen detalles técnicos en pantalla.

## Dependencias de datos

La UI no consulta SQLite directamente. El flujo queda así:

```text
DashboardPage
  -> DashboardController
    -> DashboardRepository
      -> SQLite + catálogos actuales
```

## Alcance excluido

- No se agregaron paquetes de gráficos.
- No se agregaron datos simulados en producción.
- No se duplicaron cálculos en la UI.
- No se mostraron registros inválidos dentro de los indicadores principales.
