# Sprint 4.7 - Reporte de revalidación final

Fecha de revalidación: 2026-07-31.

## Declaración

SPRINT 4.7 CERRADO.

Sprint 4.5.1 quedó cerrado antes de esta revalidación, por lo que los prerrequisitos que habían impedido cerrar Sprint 4.7 ya están corregidos y validados:

- pull incremental con cursor compuesto `updated_at + global_id`;
- cursores separados para `inspections` y `findings`;
- hallazgos remotos en `findings/{global_id}`;
- `RemoteSyncApplier` aplica remoto en SQLite sin reencolar;
- Last Write Wins probado;
- Auth Emulator + Firestore Emulator aprobados.

## Defectos encontrados durante esta revalidación

1. `AutomaticSyncCoordinator` ignoraba solicitudes concurrentes si ya había un ciclo activo. El criterio de Sprint 4.7 exige combinar esas solicitudes y permitir como máximo un ciclo adicional cuando aparecen cambios durante un ciclo.
2. `SyncStatusIndicator` podía mostrar `Actualizado` cuando la fase era `synchronized` aunque no existiera una sincronización exitosa real conocida.

## Defectos corregidos

- `AutomaticSyncCoordinator` ahora marca una solicitud concurrente como ciclo adicional pendiente y ejecuta como máximo un ciclo extra cuando termina el ciclo activo.
- `SyncStatusIndicator` solo muestra `Actualizado` cuando `SyncStatusSnapshot.isTrulySynchronized` es verdadero.
- Se agregaron pruebas para concurrencia, reinicio tras `syncing`, roles, viewer sin push y etiquetas visibles.

## Matriz de revalidación

| Área | Resultado |
|---|---|
| Coordinador usa `SyncWorker` real | OK |
| Integración con cursores 4.5.1 | OK |
| No duplica push/pull | OK |
| No hay ciclos paralelos | OK |
| Solicitudes concurrentes se combinan | OK |
| Máximo un ciclo adicional por solicitud durante ciclo activo | OK |
| “Actualizado” solo con éxito real | OK |
| Viewer nunca hace push | OK |
| Viewer conserva pendientes antiguos | OK |
| Logout/stop detiene recursos | OK |
| Reinicio con `syncing` persistido no queda colgado | OK |
| Backoff con jitter determinista | OK |
| Error técnico no se expone en UI | OK |
| Dashboard continúa desde SQLite | OK |
| Historial continúa desde SQLite | OK |
| Avance continúa desde SQLite | OK |
| Fotos/PDF/rutas/mapas/borradores excluidos | OK |
| Auth + Firestore Emulator | OK |
| APK debug | OK |

## Resultados por rol

- `administrator`: push y pull permitidos.
- `supervisor`: push y pull permitidos.
- `inspector`: push y pull permitidos.
- `viewer`: pull permitido, push bloqueado; no descarta pendientes y no marca sincronizado si existen pendientes.

## Estados visuales revalidados

- `Sincronizando...`
- `Actualizado`
- `N cambios pendientes`
- `Sin conexión`
- `Sesión requerida`
- `Error temporal`
- `Permiso insuficiente`
- `Conflicto pendiente`

El indicador incluye texto visible y no depende solo del color.

## Resultados de comandos

- `dart format .`: OK. Resultado final: `Formatted 113 files (0 changed)`.
- `flutter analyze`: OK. Resultado exacto: `No issues found! (ran in 113.6s)`.
- `flutter test test/sync_sprint_4_7_test.dart`: OK. Resultado exacto: `+26: All tests passed!`.
- `flutter test test/sync_sprint_4_5_1_test.dart`: OK. Resultado exacto: `+13: All tests passed!`.
- `flutter test`: OK. Resultado exacto: `+226: All tests passed!`.
- Auth Emulator + Firestore Emulator: OK. Comando: `firebase.cmd emulators:exec --config ..\firebase.json --project linerb --only auth,firestore "npm test"`. Resultado: `tests 10`, `pass 10`, `fail 0`, `duration_ms 9799.4149`.
- `flutter build apk --debug`: OK. Resultado exacto: `√ Built build\app\outputs\flutter-apk\app-debug.apk`.
- `git diff --check`: OK, exit code 0. No errores de whitespace. Solo advertencias CRLF de Git.

## Check opt-in de robustez

Cubierto por `test/sync_sprint_4_7_test.dart` y `test/sync_sprint_4_5_1_test.dart`:

- definición estricta de sincronizado;
- pendientes;
- sin conexión;
- sin sesión;
- perfil inactivo;
- permisos insuficientes;
- conflictos;
- operación atascada;
- backoff con jitter;
- no concurrencia;
- ciclo adicional máximo;
- logout/stop;
- dispose;
- reinicio con ciclo interrumpido;
- roles;
- prueba de estrés moderada con 100 inspecciones, hallazgos, fallos parciales y verificación de no duplicados;
- cursores compuestos;
- Last Write Wins;
- exclusiones de datos locales.

## Limitaciones pendientes

- El APK compila con una advertencia preexistente de Flutter/Kotlin Gradle Plugin para `package_info_plus`; no bloquea el build debug.
- Persisten advertencias CRLF de Git; no son errores de `git diff --check`.

## Confirmaciones de alcance

- SQLite continúa siendo la única base operativa.
- Firestore continúa siendo únicamente mecanismo remoto de intercambio.
- La UI y dashboard no consultan Firestore directamente.
- Viewer no realiza push.
- No existen timers/listeners duplicados detectados en la revalidación.
- No se modificó el informe PDF.
- No se agregó Firebase Storage.
- No se sincronizan fotografías.
- No se sincronizan rutas locales.
- No se sincronizan PDF.
- No se sincronizan mapas.
- No se sincronizan borradores.
- No se implementaron tareas con la aplicación cerrada.
