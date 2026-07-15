# Protocolo local de sincronización

## Entidades sincronizables futuras

Solo datos estructurados:

- inspecciones;
- hallazgos;
- responsables;
- tipo y nombre de línea;
- estado de línea;
- fechas y horas;
- coordenadas;
- observaciones;
- estados de sincronización;
- versiones;
- indicadores derivados.

## Entidades del Sprint 4.1

El modelo común se define únicamente para:

- `inspection`;
- `finding`.

## Estados tipados

- `pendingCreate`;
- `pendingUpdate`;
- `pendingDelete`;
- `synced`;
- `conflict`;
- `failed`.

## Operaciones de cola

- `create`;
- `update`;
- `delete`.

## Compactación

Reglas mínimas:

- `create + update` => `create` con payload estructurado más reciente.
- `update + update` => un solo `update`.
- `create + delete` antes de sincronizar => se elimina la operación remota pendiente.
- `update + delete` => `delete`.
- operaciones en conflicto no se compactan.

## Payload remoto futuro

El payload contiene datos estructurados y metadatos de sincronización.

Quedan excluidos expresamente:

- archivos de fotografía;
- bytes de imagen;
- base64;
- rutas locales de fotografías;
- PDF generado;
- archivos adjuntos locales.

## Device ID

`DeviceIdentityService` genera un identificador estable por instalación y lo guarda localmente.

No usa:

- IMEI;
- número telefónico;
- correo;
- identificadores personales sensibles.

## Estado actual

La cola queda lista para un backend futuro, pero este sprint no envía datos a internet.
