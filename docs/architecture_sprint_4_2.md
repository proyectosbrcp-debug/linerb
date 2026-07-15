# LINERB V2 - Sprint 4.2

## Objetivo

Sprint 4.2 introduce la infraestructura remota inicial con Cloud Firestore para sincronizar datos estructurados entre dispositivos.

SQLite continúa siendo la fuente operativa principal. Firestore queda como fuente remota compartida.

## Configuración Firebase

Se agregaron dependencias:

- `firebase_core`
- `cloud_firestore`

`flutterfire configure` no pudo ejecutarse en este entorno porque el comando `flutterfire` no está instalado. Queda pendiente generar `lib/firebase_options.dart` con el proyecto Firebase real.

Mientras tanto, LINERB inicializa Firebase de forma degradada: si Firebase no está disponible, la app continúa funcionando localmente con SQLite.

## Componentes agregados

- `FirebaseRuntimeInitializer`
  - Inicializa Firebase antes de `AppDependencies`.
  - Si falla, registra el problema y conserva modo local.

- `FirestoreRemoteSyncDataSource`
  - Implementa `RemoteSyncDataSource`.
  - Opera solo sobre datos estructurados.

- `InspectionRemoteMapper`
  - Construye payload remoto permitido para inspecciones.

- `FindingRemoteMapper`
  - Construye payload remoto permitido para hallazgos.

- `SyncWorker`
  - Expone `syncNow()`.
  - Procesa `sync_queue` manualmente.

- `RemoteSyncApplier`
  - Aplica cambios remotos en SQLite.
  - Evita duplicados por `global_id`.
  - Marca conflictos de versión sin sobrescribir silenciosamente.

## Principios preservados

- No se agregó autenticación.
- No se agregó Firebase Storage.
- No se sincronizan fotografías.
- No se sincronizan rutas locales.
- No se sincronizan PDFs.
- El borrador sigue exclusivamente local.
- El dashboard sigue leyendo desde SQLite.
- Fallos remotos no impiden guardar localmente.
