# Sprint 4.7 - Reporte de validación

Fecha de validación: 2026-07-31.

## Declaración

SPRINT 4.7 NO CERRADO.

Causa exacta: durante la auditoría inicial se confirmó que Sprint 4.5 no había dejado completo el prerrequisito declarado para este sprint. En particular, no existía `AutomaticSyncCoordinator` y `SyncWorker` no integraba todavía el ciclo completo con pull incremental, estado central, disparadores operativos, prevención de concurrencia y observabilidad. En este sprint se corrigió lo indispensable para que la observabilidad represente el estado real, pero por la regla explícita del alcance no se declara cerrado cuando los prerrequisitos no estaban completos al iniciar.

Validación adicional pendiente para cierre formal: existe prueba local de Firestore Rules con contextos autenticados, pero no se ejecutó una matriz end-to-end completa usando Auth Emulator + Firestore Emulator para todos los escenarios solicitados de sincronización operativa.

## Resultados de comandos

- `dart format .`: OK. Resultado final observado: `Formatted 112 files (0 changed)`.
- `flutter analyze`: OK. Resultado exacto: `No issues found! (ran in 32.7s)`.
- `flutter test test/sync_sprint_4_7_test.dart`: OK. Resultado exacto: `+20: All tests passed!`.
- `flutter test`: OK. Resultado exacto: `+207: All tests passed!`.
- `flutter build apk --debug`: OK. Resultado exacto: `√ Built build\app\outputs\flutter-apk\app-debug.apk`.
- `git diff --check`: OK, exit code 0. No errores de whitespace. Solo advertencias CRLF de Git en archivos modificados.

## Pruebas con emuladores

Comando ejecutado:

`firebase.cmd emulators:exec --config ..\firebase.json --project linerb --only firestore "npm test"` desde `firebase_tests/`.

Resultado:

- Firestore Emulator inició correctamente.
- `firebase_tests/firestore_rules_emulator_test.mjs`: 9 pruebas aprobadas.
- Resultado exacto resumido: `tests 9`, `pass 9`, `fail 0`, `duration_ms 14857.2557`.

Límite: esta validación ejercita Firestore Rules con `@firebase/rules-unit-testing` y contextos autenticados, pero no cubre Auth Emulator real ni una prueba end-to-end completa de sincronización con Auth + Firestore.

## Check opt-in de robustez

Cubierto por `test/sync_sprint_4_7_test.dart`:

- estado sincronizado real;
- pendientes;
- sin conexión;
- sin sesión;
- perfil inactivo;
- permisos insuficientes;
- conflictos;
- operación atascada;
- backoff con jitter;
- no concurrencia en sincronización manual;
- logout/stop;
- dispose;
- prueba de estrés moderada con 100 inspecciones, hallazgos, fallos parciales y verificación de no duplicados.

## Observaciones

- El APK compila con una advertencia preexistente de Flutter/Kotlin Gradle Plugin para `package_info_plus`; no bloquea el build debug.
- `git diff --check` reporta solo advertencias CRLF, sin errores.
- Se corrigió un defecto real encontrado durante validación: si SQLite no estaba disponible al restaurar el snapshot de sincronización, el coordinador propagaba la excepción. Ahora publica un estado degradado/transientFailure y no bloquea el arranque.

## Confirmaciones de alcance

- SQLite continúa siendo la única base operativa.
- Firestore funciona únicamente como mecanismo remoto de intercambio.
- La UI y el dashboard no consultan Firestore directamente.
- No se modificó el informe PDF del Sprint 4.6.
- No se agregó Firebase Storage.
- No se sincronizan fotografías.
- No se sincronizan rutas locales.
- No se sincronizan PDF.
- No se sincronizan mapas.
- No se sincronizan borradores.
- No se implementaron tareas con la aplicación cerrada.
