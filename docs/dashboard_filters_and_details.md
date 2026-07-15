# Dashboard: filtros y detalles

## Filtros disponibles

Los filtros son combinables:

- Tipo de línea:
  - todas;
  - ramal;
  - troncal;
  - subtroncal.

- Semáforo:
  - todos;
  - verde;
  - amarillo;
  - rojo.

- Responsable:
  - todos;
  - responsables disponibles en las inspecciones filtradas.

- Periodo:
  - todo el historial;
  - hoy;
  - últimos 7 días;
  - últimos 30 días;
  - personalizado.

## Limpiar filtros

El dashboard muestra la acción `Limpiar filtros` cuando existe al menos un filtro activo.

## Resultados filtrados

La pantalla principal muestra la cantidad de líneas resultantes después de aplicar filtros.

Si la combinación no produce datos, se muestra `Sin resultados para los filtros aplicados`.

## Detalle de prioridad

La pantalla de prioridad muestra:

- nombre de línea;
- tipo;
- fecha de última inspección;
- días transcurridos;
- responsable de la última inspección, cuando existe;
- estado de semáforo;
- texto `Nunca inspeccionada` cuando no existe inspección previa.

No permite edición ni eliminación.

## Detalle de hallazgos

La pantalla de hallazgos muestra:

- total filtrado;
- agrupación por categoría;
- línea;
- fecha;
- responsable;
- descripción disponible.

No muestra registros inválidos y no permite edición ni eliminación.

## Responsabilidad de cálculo

La UI no contiene fórmulas de indicadores. Los widgets solo renderizan los resultados entregados por `DashboardController`.
