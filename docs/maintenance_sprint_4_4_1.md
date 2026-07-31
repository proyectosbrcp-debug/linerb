# Sprint 4.4.1 - Mantenimiento técnico previo a sincronización automática

## Objetivo

Reducir deuda técnica antes de Sprint 4.5, eliminando avisos de `flutter analyze` sin cambiar lógica funcional, navegación, UI, autenticación, permisos, SQLite, Firestore, dashboard, PDF, fotografías ni sincronización.

## Correcciones aplicadas

### Logging centralizado

- Se amplió `AppLogger` con niveles mínimos:
  - `debug`
  - `info`
  - `warning`
  - `error`
- Se reemplazaron los `print()` de producción en `CatalogRepository` por `AppLogger`.
- Se reemplazó el `print()` del script de verificación de Auth Emulator por `stdout.writeln`, al ser salida explícita de consola.
- No se registran contraseñas, tokens, payloads de autenticación, PDF ni rutas fotográficas completas.

### DropdownButtonFormField

Se reemplazó `value` por `initialValue` en:

- `SeleccionLineaPage`
- `RegistroInspeccionPage`
- `_dropdownDetalle`

En los dropdowns dependientes se agregaron `ValueKey` mínimos para conservar la actualización visual cuando cambia:

- troncal;
- subtroncal;
- ramal;
- detalle dependiente del hallazgo.

### RadioGroup

Se migró la selección de hallazgo técnico principal a `RadioGroup<String>`.

Se conservaron:

- opciones actuales;
- valor seleccionado;
- callback de selección;
- diseño con `RadioListTile`;
- validaciones y flujo posterior.

### Geolocalización

Se reemplazó `desiredAccuracy: LocationAccuracy.high` por:

```dart
locationSettings: const LocationSettings(
  accuracy: LocationAccuracy.high,
)
```

Se conserva:

- lectura única de ubicación;
- precisión equivalente;
- formato de coordenadas;
- manejo de permisos;
- mensaje de GPS desactivado;
- mensaje de permiso denegado;
- mensaje de éxito.

## Pruebas agregadas

Archivo:

- `test/maintenance_sprint_4_4_1_test.dart`

Cobertura:

- selección inicial de dropdown;
- cambio de dropdown;
- selección dependiente troncal/subtroncal;
- selección de radio;
- captura de ubicación exitosa;
- permiso denegado;
- servicio de ubicación desactivado;
- ausencia de `print(` en `lib/` y `tool/`.

## Límites respetados

- No se cambió lógica de negocio.
- No se cambió navegación.
- No se cambió autenticación.
- No se cambiaron reglas de permisos.
- No se cambió SQLite.
- No se cambió Firestore.
- No se activó `SyncWorker` automático.
- No se agregó Firebase Storage.
- Fotografías, rutas locales, PDF y borrador permanecen locales.

## Resultado

Sprint 4.4.1 deja `flutter analyze` en cero issues.
