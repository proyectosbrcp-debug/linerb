# Arquitectura Sprint 2.5

Sprint 2.5 activa SQLite y la migración V1 dentro del ciclo real de arranque de LINERB, sin cambiar pantallas, textos, estilos ni navegación.

## Estado interno de inicialización

Archivo:

```text
lib/core/runtime/app_runtime_initializer.dart
```

Estados:

- `initializing`: apertura de SQLite y migración en curso.
- `ready`: SQLite abrió correctamente y la migración V1 terminó sin fallos operativos.
- `degraded`: SQLite o migración falló/agotó timeout; LINERB continúa con fallback V1.

## Arranque

Archivo:

```text
lib/main.dart
```

Flujo:

```text
WidgetsFlutterBinding.ensureInitialized()
  -> AppDependencies.initialize()
    -> abrir LinerbDatabase
    -> ejecutar V1DataMigrationService
    -> hidratar memoria de avance desde SQLite
  -> runApp(LinerbApp)
```

La inicialización tiene timeout para evitar bloqueo indefinido.

## Ready

Cuando el estado es `ready`:

- historial y borrador usan SQLite como fuente principal;
- `migration_metadata[v1_shared_preferences]` queda marcado como `completed`;
- avance usa la memoria hidratada desde SQLite y continúa recibiendo nuevas inspecciones en memoria.

## Degraded

Cuando el estado es `degraded`:

- LINERB no impide que el usuario continúe;
- historial y borrador usan `SharedPreferencesStorage`;
- las claves V1 permanecen disponibles;
- el error se registra con logging interno centralizado;
- no se muestran detalles técnicos al usuario.

## Logging

Archivo:

```text
lib/core/logging/app_logger.dart
```

Usa `dart:developer`.

No se agregaron nuevos `print()`.

## Guardado de inspección finalizada

El flujo visible no cambia.

Internamente, `ResumenInspeccionPage` llama:

```text
InspectionRepository.guardarInspeccionCompleta(inspeccion, hallazgos)
```

En SQLite:

- se guarda la inspección en `inspections`;
- se guardan hallazgos asociados por `inspection_id`;
- se mantiene la inserción en memoria para avance;
- el borrador se borra solo después de guardar correctamente.

En fallback V1:

- se mantiene el formato anterior de `historial_inspecciones`;
- los hallazgos no se agregan al historial visible, igual que V1.

## Borrador

En `ready`:

- se guarda en SQLite;
- se restaura desde SQLite;
- se borra al finalizar correctamente.

En `degraded`:

- se usa el borrador V1 en `SharedPreferences`.

Si falla la finalización, el borrador no se elimina porque el borrado ocurre después del guardado exitoso.

## Controllers

Los controllers siguen sin depender de Flutter UI:

- no importan `package:flutter/material.dart`;
- no usan `BuildContext`;
- no usan `Navigator`;
- no usan `ScaffoldMessenger`;
- no usan `Widget`;
- no usan `showDialog`.

## Compatibilidad V1

Se conservan:

- `SharedPreferencesStorage`;
- claves V1;
- fallback V1;
- cache de catálogos en `SharedPreferences`;
- formato visible de historial, borrador, avance e inspecciones.
