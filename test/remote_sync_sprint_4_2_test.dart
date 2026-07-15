import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/core/time/app_clock.dart';
import 'package:linerb/models/draft_data.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/models/sync_models.dart';
import 'package:linerb/repositories/remote/finding_remote_mapper.dart';
import 'package:linerb/repositories/remote/inspection_remote_mapper.dart';
import 'package:linerb/repositories/remote/remote_mapping_exception.dart';
import 'package:linerb/repositories/sync_repository.dart';
import 'package:linerb/services/remote_sync_applier.dart';
import 'package:linerb/services/sync_worker.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_database_storage.dart';
import 'package:linerb/storage/local/local_sync_metadata_storage.dart';
import 'package:linerb/storage/local/local_sync_queue_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LinerbDatabase database;
  late _FixedClock clock;
  late LocalSyncQueueStorage queueStorage;
  late LocalSyncMetadataStorage metadataStorage;
  late LocalDatabaseStorage localStorage;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    clock = _FixedClock(DateTime(2026, 5, 1, 10));
    database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    queueStorage = LocalSyncQueueStorage(database: database, clock: clock);
    metadataStorage = LocalSyncMetadataStorage(database: database);
    localStorage = LocalDatabaseStorage(
      database: database,
      inspeccionesMemoria: [],
      clock: clock,
      deviceIdProvider: () async => 'device-test',
      syncQueueStorage: queueStorage,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('mapper de inspección construye payload remoto sin fotografías', () {
    const mapper = InspectionRemoteMapper();
    final payload = mapper.fromLocalPayload(_inspectionPayload());

    expect(payload['global_id'], 'inspection-1');
    expect(payload['fecha'], isA<Timestamp>());
    expect(
      payload.keys.any((key) => key.toLowerCase().contains('foto')),
      isFalse,
    );
    expect(
      payload.keys.any((key) => key.toLowerCase().contains('pdf')),
      isFalse,
    );
  });

  test('mapper de hallazgo construye payload remoto sin fotografías', () {
    const mapper = FindingRemoteMapper();
    final payload = mapper.fromLocalPayload(_findingPayload());

    expect(payload['global_id'], 'finding-1');
    expect(payload['inspection_global_id'], 'inspection-1');
    expect(
      payload.keys.any((key) => key.toLowerCase().contains('foto')),
      isFalse,
    );
  });

  test('mappers rechazan PDF, rutas locales y Base64', () {
    const inspectionMapper = InspectionRemoteMapper();
    const findingMapper = FindingRemoteMapper();

    expect(
      () => inspectionMapper.fromLocalPayload({
        ..._inspectionPayload(),
        'pdf_path': '/tmp/reporte.pdf',
      }),
      throwsA(isA<RemoteMappingException>()),
    );
    expect(
      () => findingMapper.fromLocalPayload({
        ..._findingPayload(),
        'foto1_path': '/tmp/foto.jpg',
      }),
      throwsA(isA<RemoteMappingException>()),
    );
    expect(
      () => findingMapper.fromLocalPayload({
        ..._findingPayload(),
        'base64': 'abc',
      }),
      throwsA(isA<RemoteMappingException>()),
    );
  });

  test('procesa cola exitosamente con batch inspección + hallazgos', () async {
    await localStorage.agregarInspeccionCompleta(_inspection(), [_finding()]);
    final remote = _FakeRemoteSyncDataSource();
    final worker = SyncWorker(
      queueStorage: queueStorage,
      metadataStorage: metadataStorage,
      remoteDataSource: remote,
      clock: clock,
    );

    final result = await worker.syncNow();

    expect(result.status, SyncWorkerStatus.synced);
    expect(result.processed, 2);
    expect(remote.batches, hasLength(1));
    expect(await queueStorage.pendingOperations(), isEmpty);
  });

  test(
    'creación, actualización y borrado lógico remoto son enrutados',
    () async {
      final remote = _FakeRemoteSyncDataSource();

      await remote.createInspection(_inspectionPayload());
      await remote.updateInspection(_inspectionPayload());
      await remote.deleteInspection({
        ..._inspectionPayload(),
        'deleted_at': DateTime(2026, 5, 1).toIso8601String(),
      });
      await remote.createFinding(_findingPayload());
      await remote.updateFinding(_findingPayload());
      await remote.deleteFinding({
        ..._findingPayload(),
        'deleted_at': DateTime(2026, 5, 1).toIso8601String(),
      });

      expect(remote.createdInspections, hasLength(1));
      expect(remote.updatedInspections, hasLength(1));
      expect(remote.deletedInspections, hasLength(1));
      expect(remote.createdFindings, hasLength(1));
      expect(remote.updatedFindings, hasLength(1));
      expect(remote.deletedFindings, hasLength(1));
    },
  );

  test('fallo remoto registra reintento sin borrar la cola', () async {
    await localStorage.agregarInspeccionCompleta(_inspection(), const []);
    final remote = _FakeRemoteSyncDataSource(failPush: true);
    final worker = SyncWorker(
      queueStorage: queueStorage,
      metadataStorage: metadataStorage,
      remoteDataSource: remote,
      clock: clock,
    );

    final result = await worker.syncNow();
    final pending = await queueStorage.pendingOperations();

    expect(result.status, SyncWorkerStatus.partialFailure);
    expect(pending.single.attempts, 1);
    expect(pending.single.lastError, contains('fallo remoto'));
    expect(pending.single.nextAttemptAt, isNotNull);
  });

  test('inspección principal fallida bloquea hallazgos dependientes', () async {
    await localStorage.agregarInspeccionCompleta(_inspection(), [_finding()]);
    final remote = _FakeRemoteSyncDataSource(failPush: true);
    final worker = SyncWorker(
      queueStorage: queueStorage,
      metadataStorage: metadataStorage,
      remoteDataSource: remote,
      clock: clock,
    );

    final result = await worker.syncNow();
    final pending = await queueStorage.pendingOperations();

    expect(result.failed, 1);
    expect(pending, hasLength(2));
    expect(pending.where((item) => item.attempts == 1), hasLength(1));
  });

  test('descarga cambios y evita duplicados por global_id', () async {
    final applier = RemoteSyncApplier(database: database);
    final changes = RemoteChangeSet(
      inspections: [_remoteInspection()],
      findings: [_remoteFinding()],
      cursor: DateTime(2026, 5, 1, 11),
    );

    await applier.apply(changes);
    await applier.apply(changes);

    final db = await database.open();
    expect(await db.query('inspections'), hasLength(1));
    expect(await db.query('hallazgos'), hasLength(1));
    expect(await applier.loadCursor(), DateTime(2026, 5, 1, 11));
  });

  test(
    'conflicto de versiones marca conflict y conserva copia local',
    () async {
      await localStorage.agregarInspeccionCompleta(_inspection(), const []);
      final applier = RemoteSyncApplier(database: database);
      final db = await database.open();
      final local = (await db.query('inspections')).single;
      final globalId = local['global_id'] as String;

      await applier.apply(
        RemoteChangeSet(
          inspections: [
            {
              ..._remoteInspection(),
              'global_id': globalId,
              'remote_version': 5,
              'responsable': 'Remoto',
            },
          ],
          findings: const [],
          cursor: DateTime(2026, 5, 1, 11),
        ),
      );

      final row = (await db.query('inspections')).single;
      expect(row['sync_status'], syncStatusToStorage(SyncStatus.conflict));
      expect(row['responsable'], 'Operador');
    },
  );

  test('datos remotos incompletos se toleran sin derribar', () {
    const mapper = InspectionRemoteMapper();

    expect(mapper.fromRemote({'responsable': 'Sin ID'}), isNull);
  });

  test('funcionamiento local cuando Firebase no está disponible', () async {
    await localStorage.agregarInspeccionCompleta(_inspection(), const []);
    final worker = SyncWorker(
      queueStorage: queueStorage,
      metadataStorage: metadataStorage,
      remoteDataSource: null,
      clock: clock,
    );

    final result = await worker.syncNow();

    expect(result.status, SyncWorkerStatus.unavailable);
    expect(await localStorage.inspectionCount(), 1);
  });

  test(
    'dashboard y borrador permanecen locales frente a sincronización remota',
    () async {
      await localStorage.guardarBorrador(_draft());
      final queue = await queueStorage.pendingOperations();

      expect(queue, isEmpty);
    },
  );
}

Map<String, Object?> _inspectionPayload() {
  return {
    'global_id': 'inspection-1',
    'fecha_iso': DateTime(2026, 5, 1).toIso8601String(),
    'responsable': 'Operador',
    'tipo_linea': 'Ramal',
    'linea': 'RAMAL 1',
    'punto_referencia': 'KM 1',
    'estado_linea': 'Operativa',
    'observaciones': 'Sin novedad',
    'created_at': DateTime(2026, 5, 1).toIso8601String(),
    'updated_at': DateTime(2026, 5, 1).toIso8601String(),
    'created_by': 'local_user',
    'updated_by': 'local_user',
    'device_id': 'device-test',
    'local_version': 1,
    'remote_version': 0,
    'sync_status': 'pendingCreate',
    'deleted_at': null,
  };
}

Map<String, Object?> _findingPayload() {
  return {
    'global_id': 'finding-1',
    'inspection_id': 'inspection-1',
    'tipo': 'Fuga',
    'detalle': 'Leve',
    'descripcion': 'Hallazgo',
    'latitud': '1',
    'longitud': '2',
    'created_at': DateTime(2026, 5, 1).toIso8601String(),
    'updated_at': DateTime(2026, 5, 1).toIso8601String(),
    'created_by': 'local_user',
    'updated_by': 'local_user',
    'device_id': 'device-test',
    'local_version': 1,
    'remote_version': 0,
    'deleted_at': null,
  };
}

Map<String, Object?> _remoteInspection() {
  return {
    'global_id': 'inspection-remote-1',
    'fecha': Timestamp.fromDate(DateTime(2026, 5, 1)),
    'responsable': 'Operador',
    'tipo_linea': 'Ramal',
    'linea': 'RAMAL 1',
    'punto_referencia': 'KM 1',
    'estado_linea': 'Operativa',
    'observacion_general': 'Remota',
    'created_at': Timestamp.fromDate(DateTime(2026, 5, 1)),
    'updated_at': Timestamp.fromDate(DateTime(2026, 5, 1)),
    'created_by': 'remote',
    'updated_by': 'remote',
    'device_id': 'device-remote',
    'local_version': 1,
    'remote_version': 1,
    'sync_status': 'synced',
    'deleted_at': null,
  };
}

Map<String, Object?> _remoteFinding() {
  return {
    'global_id': 'finding-remote-1',
    'inspection_global_id': 'inspection-remote-1',
    'categoria': 'Fuga',
    'subcategoria': 'Leve',
    'descripcion': 'Hallazgo remoto',
    'latitud': '1',
    'longitud': '2',
    'created_at': Timestamp.fromDate(DateTime(2026, 5, 1)),
    'updated_at': Timestamp.fromDate(DateTime(2026, 5, 1)),
    'created_by': 'remote',
    'updated_by': 'remote',
    'device_id': 'device-remote',
    'local_version': 1,
    'remote_version': 1,
    'deleted_at': null,
  };
}

Inspeccion _inspection() {
  return Inspeccion(
    linea: 'RAMAL 1',
    tipoLinea: 'Ramal',
    responsable: 'Operador',
    fecha: DateTime(2026, 5, 1),
    estadoLinea: 'Operativa',
    puntoReferencia: 'KM 1',
    observaciones: 'Sin novedad',
  );
}

HallazgoInspeccion _finding() {
  return HallazgoInspeccion(
    tipo: 'Fuga',
    detalle: 'Leve',
    latitud: '1',
    longitud: '2',
    descripcion: 'Hallazgo',
    foto1Path: '/local/foto1.jpg',
    foto2Path: '/local/foto2.jpg',
  );
}

DraftData _draft() {
  return DraftData(
    usuario: 'SUPER',
    tipoLinea: 'Ramal',
    seleccionLinea: 'RAMAL 1',
    responsable: 'Operador',
    puntoReferencia: 'KM 1',
    estadoLinea: 'Operativa',
    hallazgos: [_finding()],
  );
}

class _FixedClock implements Clock {
  final DateTime value;

  const _FixedClock(this.value);

  @override
  DateTime now() => value;
}

class _FakeRemoteSyncDataSource implements RemoteSyncDataSource {
  final bool failPush;
  final createdInspections = <Map<String, Object?>>[];
  final updatedInspections = <Map<String, Object?>>[];
  final deletedInspections = <Map<String, Object?>>[];
  final createdFindings = <Map<String, Object?>>[];
  final updatedFindings = <Map<String, Object?>>[];
  final deletedFindings = <Map<String, Object?>>[];
  final batches = <List<SyncQueueEntry>>[];

  _FakeRemoteSyncDataSource({this.failPush = false});

  @override
  Future<void> push(SyncQueueEntry operation) async {
    if (failPush) throw StateError('fallo remoto');
    final payload = Map<String, Object?>.from(
      jsonDecode(operation.payloadJson),
    );
    switch ((operation.entityType, operation.operation)) {
      case (SyncEntityType.inspection, SyncOperationType.create):
        await createInspection(payload);
      case (SyncEntityType.inspection, SyncOperationType.update):
        await updateInspection(payload);
      case (SyncEntityType.inspection, SyncOperationType.delete):
        await deleteInspection(payload);
      case (SyncEntityType.finding, SyncOperationType.create):
        await createFinding(payload);
      case (SyncEntityType.finding, SyncOperationType.update):
        await updateFinding(payload);
      case (SyncEntityType.finding, SyncOperationType.delete):
        await deleteFinding(payload);
    }
  }

  @override
  Future<void> pushBatch(List<SyncQueueEntry> operations) async {
    if (failPush) throw StateError('fallo remoto');
    batches.add(operations);
  }

  @override
  Future<void> createInspection(Map<String, Object?> payload) async {
    createdInspections.add(payload);
  }

  @override
  Future<void> updateInspection(Map<String, Object?> payload) async {
    updatedInspections.add(payload);
  }

  @override
  Future<void> deleteInspection(Map<String, Object?> payload) async {
    deletedInspections.add(payload);
  }

  @override
  Future<void> createFinding(Map<String, Object?> payload) async {
    createdFindings.add(payload);
  }

  @override
  Future<void> updateFinding(Map<String, Object?> payload) async {
    updatedFindings.add(payload);
  }

  @override
  Future<void> deleteFinding(Map<String, Object?> payload) async {
    deletedFindings.add(payload);
  }

  @override
  Future<RemoteChangeSet> fetchChanges({DateTime? since}) async {
    return RemoteChangeSet(
      inspections: [_remoteInspection()],
      findings: [_remoteFinding()],
      cursor: DateTime(2026, 5, 1),
    );
  }

  @override
  Future<List<Map<String, Object?>>> fetchFindingsForInspections(
    List<String> inspectionGlobalIds,
  ) async {
    return [_remoteFinding()];
  }
}
