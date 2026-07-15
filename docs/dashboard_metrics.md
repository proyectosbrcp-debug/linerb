# Indicadores del dashboard

Este documento define los indicadores calculados por el motor de dashboard de Sprint 3.1.

## Modelos

```text
DashboardSummary
LineInspectionStatus
FindingCategorySummary
InspectionPeriodSummary
ResponsibleInspectionSummary
```

## Indicadores

### totalCatalogLines

Total de líneas únicas del catálogo actual.

Fuente:

- `CatalogData.troncalesJson`
- `CatalogData.ramalesJson`

Normalización:

- usa `LineIdentityNormalizer`.

### inspectedLines

Cantidad de líneas del catálogo que tienen al menos una inspección válida en SQLite.

Fuente:

- catálogo actual;
- `inspections.is_invalid = 0`.

### neverInspectedLines

Cantidad de líneas del catálogo sin inspecciones válidas.

Fuente:

- catálogo actual;
- inspecciones válidas en SQLite.

### coveragePercentage

Porcentaje de cobertura.

Fórmula:

```text
inspectedLines / totalCatalogLines * 100
```

Si `totalCatalogLines = 0`, retorna `0`.

### totalInspections

Total de inspecciones válidas.

Fuente:

- `inspections`
- filtro `is_invalid = 0`.

### totalFindings

Total de hallazgos válidos asociados a inspecciones.

Fuente:

- `hallazgos`
- filtro `is_invalid = 0`
- `inspection_id IS NOT NULL`.

### findingsByCategory

Hallazgos agrupados por categoría técnica.

Fuente:

- `hallazgos.tipo`
- solo hallazgos válidos.

### dailyInspections

Inspecciones válidas agrupadas por día.

Periodo:

```text
DateTime(year, month, day)
```

### weeklyInspections

Inspecciones válidas agrupadas por semana.

Semana inicia lunes.

### monthlyInspections

Inspecciones válidas agrupadas por mes.

Periodo:

```text
DateTime(year, month)
```

### greenLines / yellowLines / redLines

Cantidad de líneas de catálogo por estado de semáforo.

Reglas:

- verde: 0 a 15 días;
- amarillo: más de 15 y hasta 60 días;
- rojo: más de 60 días o nunca inspeccionada.

### lineStatuses

Listado priorizado de líneas del catálogo.

Incluye:

- nombre normalizado;
- tipo de línea;
- fecha de última inspección;
- cantidad de inspecciones;
- estado del semáforo;
- días desde última inspección.

Orden:

1. rojo;
2. amarillo;
3. verde;
4. más vencida primero;
5. nombre normalizado.

### inspectionsByResponsible

Inspecciones válidas agrupadas por responsable.

Fuente:

- `inspections.responsable`
- filtro `is_invalid = 0`.

### invalidRecordsExcluded

Cantidad de registros inválidos excluidos de los indicadores principales.

Fuente:

- `inspections.is_invalid = 1`
- `hallazgos.is_invalid = 1`
- `draft.is_invalid = 1`

## Exclusiones

Los indicadores principales no incluyen registros marcados como inválidos.

El motor no modifica ni repara datos: solo calcula.
