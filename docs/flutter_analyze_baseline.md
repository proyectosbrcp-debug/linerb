# Flutter analyze baseline - Sprint 4.4.1

## Baseline inicial

Cantidad inicial de infos: 22.

No había errores ni warnings bloqueantes.

### deprecated_member_use

9 avisos:

1. `lib/pages/home/seleccion_linea_page.dart:142` - `DropdownButtonFormField.value`
2. `lib/pages/home/seleccion_linea_page.dart:173` - `DropdownButtonFormField.value`
3. `lib/pages/home/seleccion_linea_page.dart:196` - `DropdownButtonFormField.value`
4. `lib/pages/home/seleccion_linea_page.dart:219` - `DropdownButtonFormField.value`
5. `lib/pages/inspeccion/registro_inspeccion_page.dart:168` - `desiredAccuracy`
6. `lib/pages/inspeccion/registro_inspeccion_page.dart:253` - `DropdownButtonFormField.value`
7. `lib/pages/inspeccion/registro_inspeccion_page.dart:292` - `Radio.groupValue`
8. `lib/pages/inspeccion/registro_inspeccion_page.dart:293` - `Radio.onChanged`
9. `lib/pages/inspeccion/registro_inspeccion_page.dart:562` - `DropdownButtonFormField.value`

### avoid_print

13 avisos:

1. `lib/repositories/catalog_repository.dart:25`
2. `lib/repositories/catalog_repository.dart:38`
3. `lib/repositories/catalog_repository.dart:50`
4. `lib/repositories/catalog_repository.dart:51`
5. `lib/repositories/catalog_repository.dart:55`
6. `lib/repositories/catalog_repository.dart:59`
7. `lib/repositories/catalog_repository.dart:65`
8. `lib/repositories/catalog_repository.dart:66`
9. `lib/repositories/catalog_repository.dart:70`
10. `lib/repositories/catalog_repository.dart:80`
11. `lib/repositories/catalog_repository.dart:87`
12. `lib/repositories/catalog_repository.dart:88`
13. `tool/auth_controller_emulator_check.dart:27`

### Otros

0 avisos.

## Correcciones

- `avoid_print`: reemplazado por `AppLogger` en código de producción y `stdout.writeln` en script de consola.
- `DropdownButtonFormField.value`: reemplazado por `initialValue`.
- `Radio.groupValue` / `Radio.onChanged`: migrado a `RadioGroup`.
- `desiredAccuracy`: reemplazado por `LocationSettings`.

## Baseline final

Cantidad final de issues: 0.

Resultado final:

```text
No issues found!
```

## Avisos restantes

No quedan avisos restantes.
