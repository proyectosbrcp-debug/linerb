# Sprint 4.5.1 - Validación de cierre técnico

Fecha de validación: 2026-07-31.

## Declaración

SPRINT 4.5.1 CERRADO.

El motor de sincronización automática quedó completo para los prerrequisitos auditados: push, pull incremental, cursores compuestos, cursores independientes, cola persistente, reintentos, Last Write Wins, aplicación remota sobre SQLite sin reencolar y validación con emuladores.

## Defectos encontrados

- No existía documentación `docs/architecture_sprint_4_5.md`.
- El pull incremental dependía de un cursor único de fecha.
- No había cursor compuesto `updated_at + global_id`.
- No había cursores independientes por colección.
- `FirestoreRemoteSyncDataSource` escribía hallazgos en subcolección de inspección.
- La documentación decía que los hallazgos vivían en subcolección.
- La prueba histórica de conflicto no estaba alineada con Last Write Wins.

## Defectos corregidos

- Se agregó `SyncCursor` y `RemoteSyncCursors`.
- Se persistieron cursores independientes para `inspections` y `findings`.
- `SyncWorker` ahora solicita pull con cursores compuestos.
- `FirestoreRemoteSyncDataSource` usa `inspections/{global_id}` y `findings/{global_id}`.
- `RemoteSyncApplier` aplica cambios remotos en SQLite sin reencolar.
- `RemoteSyncApplier` resuelve Last Write Wins por timestamp, tolerancia de clock skew, versión y desempate determinista.
- Se actualizó la caracterización de sync remoto para reflejar Last Write Wins.
- Se agregó prueba real de Auth Emulator.

## Pruebas agregadas

- `test/sync_sprint_4_5_1_test.dart`
- `firebase_tests/auth_emulator_test.mjs`

Cobertura nueva:

- cursores independientes;
- comparación `updated_at + global_id`;
- aplicación remota sin reencolar;
- local más reciente;
- remoto más reciente;
- timestamps iguales y versiones distintas;
- clock skew razonable;
- compactación de cola;
- exclusión de fotos, PDF, borrador, rutas y mapa;
- dashboard, historial y avance sin imports Firestore;
- Auth Emulator: crear usuario, cerrar sesión e iniciar sesión sin producción.

## Resultados de validación

- `dart format .`: OK. Resultado final: `Formatted 113 files (0 changed)`.
- `flutter analyze`: OK. Resultado exacto: `No issues found! (ran in 42.4s)`.
- `flutter test test/sync_sprint_4_5_1_test.dart`: OK. Resultado: 13 pruebas aprobadas.
- Pruebas específicas Sync: OK. `remote_sync_sprint_4_2_test.dart`, `sync_sprint_4_5_1_test.dart` y `sync_sprint_4_7_test.dart` aprobaron en conjunto 45 pruebas.
- `flutter test`: OK. Resultado exacto: `+220: All tests passed!`.
- Auth Emulator + Firestore Emulator: OK. Comando: `firebase.cmd emulators:exec --config ..\firebase.json --project linerb --only auth,firestore "npm test"`. Resultado: `tests 10`, `pass 10`, `fail 0`.
- `flutter build apk --debug`: OK. Resultado exacto: `√ Built build\app\outputs\flutter-apk\app-debug.apk`.
- `git diff --check`: OK, sin errores; solo advertencias CRLF de Git.

## Confirmaciones

- SQLite sigue siendo la única base operativa.
- Firestore sigue siendo únicamente mecanismo remoto de intercambio.
- Dashboard nunca consulta Firestore.
- Historial nunca consulta Firestore.
- Avance nunca consulta Firestore.
- No existe sincronización paralela en `AutomaticSyncCoordinator`.
- No existen timers duplicados en el coordinador.
- No existen listeners duplicados introducidos en este cierre.
- No se sincronizan fotografías.
- No se sincronizan PDF.
- No se sincronizan mapas.
- No se sincronizan rutas locales.
- No se sincronizan borradores.
- No se agregó Firebase Storage.
