# Dashboard UI

## Estructura visual

La pantalla `DashboardPage` muestra:

1. Resumen general:
   - porcentaje de cobertura;
   - líneas inspeccionadas;
   - líneas pendientes;
   - total de inspecciones.

2. Semáforo de líneas:
   - verdes;
   - amarillas;
   - rojas.

3. Prioridad de inspección:
   - máximo 10 líneas;
   - nombre de línea;
   - tipo de línea;
   - fecha de última inspección;
   - estado de semáforo;
   - texto `Nunca inspeccionada` cuando no existe inspección previa.

4. Hallazgos y responsables:
   - total de hallazgos;
   - principales categorías de hallazgo;
   - inspecciones por responsable.

## Reglas de presentación

- La pantalla usa el color principal actual de LINERB: `0xFF0D47A1`.
- El fondo conserva el tono `0xFFF4F7FA`.
- El contenido usa scroll vertical para mantener compatibilidad con teléfonos pequeños.
- Los grupos se mantienen resumidos para evitar saturación visual.

## Reglas de negocio

La pantalla no calcula indicadores. Solo presenta el resultado de `DashboardController.loadSummary()`.

Las reglas del semáforo, normalización de líneas, exclusión de registros inválidos y agrupaciones siguen centralizadas en el motor de Sprint 3.1.

## Manejo de errores

Los errores técnicos se registran con `AppLogger.warning`.

Al usuario solo se le muestra:

`No se pudo cargar el dashboard. Intente nuevamente más tarde.`
