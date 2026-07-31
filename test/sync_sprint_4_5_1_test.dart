import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/core/time/app_clock.dart';
import 'package:linerb/models/sync_models.dart';
import 'package:linerb/repositories/remote/finding_remote_mapper.dart';
import 'package:linerb/repositories/remote/inspection_remote_mapper.dart';
import 'package:linerb/repositories/remote/remote_mapping_exception.dart';
import 'package:linerb/services/remote_sync_applier.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_sync_queue_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LinerbDatabase database;
  late LocalSyncQueueStorage queueStorage;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    queueStorage = LocalSyncQueueStorage(
      database: database,
      clock: _FixedClock(DateTime(2026, 7, 31, 10)),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Sprint 4.5.1 cursores incrementales', () {
    test('persiste cursores independientes por colecciÃ³n', () async {
      final applier = RemoteSyncApplier(database: database);
      final inspectionCursor = SyncCursor(
        updatedAt: DateTime(2026, 7, 31, 10),
        globalId: 'inspection-z',
      );
      final findingCursor = SyncCursor(
        updatedAt: DateTime(2026, 7, 31, 11),
        globalId: 'finding-z',
      );

      await applier.apply(
        RemoteChangeSet(
          inspections: [_remoteInspection('inspection-z')],
          findings: [_remoteFinding('finding-z', 'inspection-z')],
          cursor: inspectionCursor.updatedAt,
          inspectionsCursor: inspectionCursor,
          findingsCursor: findingCursor,
        ),
      );

      final cursors = await applier.loadCursors();
      expect(cursors.inspections?.updatedAt, inspectionCursor.updatedAt);
      expect(cursors.inspections?.globalId, 'inspection-z');
      expect(cursors.findings?.updatedAt, findingCursor.updatedAt);
      expect(cursors.findings?.globalId, 'finding-z');
      expect(await applier.loadCursor(), inspectionCursor.updatedAt);
    });

    test('SyncCursor usa updated_at y global_id como cursor compuesto', () {
      final cursor = SyncCursor(
        updatedAt: DateTime(2026, 7, 31, 10),
        globalId: 'b',
      );

      expect(cursor.isBeforeRemote(DateTime(2026, 7, 31, 10), 'a'), isFalse);
      expect(cursor.isBeforeRemote(DateTime(2026, 7, 31, 10), 'b'), isFalse);
      expect(cursor.isBeforeRemote(DateTime(2026, 7, 31, 10), 'c'), isTrue);
      expect(cursor.isBeforeRemote(DateTime(2026, 7, 31, 10, 1), 'a'), isTrue);
    });
  });

  group('Sprint 4.5.1 aplicaciÃ³n remota y Last Write Wins', () {
    test('aplica remoto sin reencolar operaciones', () async {
      final applier = RemoteSyncApplier(database: database);

      await applier.apply(
        RemoteChangeSet(
          inspections: [_remoteInspection('inspection-1')],
          findings: [_remoteFinding('finding-1', 'inspection-1')],
          cursor: DateTime(2026, 7, 31, 10),
        ),
      );

      expect(await queueStorage.pendingOperations(), isEmpty);
    });

    test('local mÃ¡s reciente conserva pendiente local', () async {
      await _insertInspection(
        database,
        id: 'inspection-1',
        responsable: 'Local',
        updatedAt: DateTime(2026, 7, 31, 12),
        remoteVersion: 1,
        syncStatus: SyncStatus.pendingUpdate,
      );
      final applier = RemoteSyncApplier(database: database);

      await applier.apply(
        RemoteChangeSet(
          inspections: [
            _remoteInspection(
              'inspection-1',
              responsable: 'Remoto',
              updatedAt: DateTime(2026, 7, 31, 10),
              remoteVersion: 5,
            ),
          ],
          findings: const [],
          cursor: DateTime(2026, 7, 31, 10),
        ),
      );

      final row = await _singleInspection(database);
      expect(row['responsable'], 'Local');
      expect(row['sync_status'], syncStatusToStorage(SyncStatus.pendingUpdate));
    });

    test('remoto mÃ¡s reciente gana y queda synced', () async {
      await _insertInspection(
        database,
        id: 'inspection-1',
        responsable: 'Local',
        updatedAt: DateTime(2026, 7, 31, 10),
        remoteVersion: 1,
        syncStatus: SyncStatus.pendingUpdate,
      );
      final applier = RemoteSyncApplier(database: database);

      await applier.apply(
        RemoteChangeSet(
          inspections: [
            _remoteInspection(
              'inspection-1',
              responsable: 'Remoto',
              updatedAt: DateTime(2026, 7, 31, 12),
              remoteVersion: 2,
            ),
          ],
          findings: const [],
          cursor: DateTime(2026, 7, 31, 12),
        ),
      );

      final row = await _singleInspection(database);
      expect(row['responsable'], 'Remoto');
      expect(row['sync_status'], syncStatusToStorage(SyncStatus.synced));
    });

    test('timestamps iguales se resuelven por versiÃ³n remota', () async {
      final timestamp = DateTime(2026, 7, 31, 10);
      await _insertInspection(
        database,
        id: 'inspection-1',
        responsable: 'Local',
        updatedAt: timestamp,
        remoteVersion: 1,
        syncStatus: SyncStatus.pendingUpdate,
      );
      final applier = RemoteSyncApplier(database: database);

      await applier.apply(
        RemoteChangeSet(
          inspections: [
            _remoteInspection(
              'inspection-1',
              responsable: 'Remoto',
              updatedAt: timestamp,
              remoteVersion: 2,
            ),
          ],
          findings: const [],
          cursor: timestamp,
        ),
      );

      expect((await _singleInspection(database))['responsable'], 'Remoto');
    });

    test('clock skew razonable usa versiÃ³n para decidir', () async {
      await _insertInspection(
        database,
        id: 'inspection-1',
        responsable: 'Local',
        updatedAt: DateTime(2026, 7, 31, 10),
        remoteVersion: 3,
        syncStatus: SyncStatus.pendingUpdate,
      );
      final applier = RemoteSyncApplier(database: database);

      await applier.apply(
        RemoteChangeSet(
          inspections: [
            _remoteInspection(
              'inspection-1',
              responsable: 'Remoto',
              updatedAt: DateTime(2026, 7, 31, 10, 3),
              remoteVersion: 2,
            ),
          ],
          findings: const [],
          cursor: DateTime(2026, 7, 31, 10, 3),
        ),
      );

      expect((await _singleInspection(database))['responsable'], 'Local');
    });
  });

  group('Sprint 4.5.1 compactaciÃ³n de cola', () {
    test('create + update conserva create con payload actualizado', () async {
      await queueStorage.enqueue(_operation(SyncOperationType.create, 'A'));
      await queueStorage.enqueue(_operation(SyncOperationType.update, 'B'));

      final pending = await queueStorage.pendingOperations();
      expect(pending, hasLength(1));
      expect(pending.single.operation, SyncOperationType.create);
      expect(pending.single.payloadJson, contains('"valor":"B"'));
    });

    test('create + delete elimina operaciÃ³n imposible', () async {
      await queueStorage.enqueue(_operation(SyncOperationType.create, 'A'));
      await queueStorage.enqueue(_operation(SyncOperationType.delete, 'B'));

      expect(await queueStorage.pendingOperations(), isEmpty);
    });

    test('update + update conserva un solo update', () async {
      await queueStorage.enqueue(_operation(SyncOperationType.update, 'A'));
      await queueStorage.enqueue(_operation(SyncOperationType.update, 'B'));

      final pending = await queueStorage.pendingOperations();
      expect(pending, hasLength(1));
      expect(pending.single.operation, SyncOperationType.update);
      expect(pending.single.payloadJson, contains('"valor":"B"'));
    });

    test('update + delete compacta a delete', () async {
      await queueStorage.enqueue(_operation(SyncOperationType.update, 'A'));
      await queueStorage.enqueue(_operation(SyncOperationType.delete, 'B'));

      final pending = await queueStorage.pendingOperations();
      expect(pending, hasLength(1));
      expect(pending.single.operation, SyncOperationType.delete);
    });
  });

  group('Sprint 4.5.1 lÃ­mites de sincronizaciÃ³n', () {
    test('mappers rechazan fotos, pdf, borrador, rutas y mapa', () {
      const inspectionMapper = InspectionRemoteMapper();
      const findingMapper = FindingRemoteMapper();

      for (final forbidden in const [
        'foto1_path',
        'pdf_path',
        'borrador_id',
        'ruta_local',
        'map_image_path',
      ]) {
        expect(
          () => inspectionMapper.fromLocalPayload({
            ..._inspectionPayload('inspection-1'),
            forbidden: 'local',
          }),
          throwsA(isA<RemoteMappingException>()),
        );
        expect(
          () => findingMapper.fromLocalPayload({
            ..._findingPayload('finding-1', 'inspection-1'),
            forbidden: 'local',
          }),
          throwsA(isA<RemoteMappingException>()),
        );
      }
    });

    test('dashboard, historial y avance no importan Firestore', () {
      for (final path in const [
        'lib/controllers/dashboard_controller.dart',
        'lib/pages/dashboard/dashboard_page.dart',
        'lib/pages/historial/historial_page.dart',
        'lib/pages/avance/avance_page.dart',
      ]) {
        final content = File(path).readAsStringSync();
        expect(content, isNot(contains('cloud_firestore')));
        expect(content, isNot(contains('FirebaseFirestore')));
      }
    });
  });
}

class _FixedClock implements Clock {
  final DateTime value;

  const _FixedClock(this.value);

  @override
  DateTime now() => value;
}

SyncQueueOperation _operation(SyncOperationType operation, String value) {
  return SyncQueueOperation(
    entityType: SyncEntityType.inspection,
    entityId: 'inspection-1',
    operation: operation,
    payloadJson: jsonEncode({'global_id': 'inspection-1', 'valor': value}),
  );
}

Map<String, Object?> _inspectionPayload(String id) {
  return {
    'global_id': id,
    'fecha_iso': DateTime(2026, 7, 31).toIso8601String(),
    'responsable': 'Operador',
    'tipo_linea': 'Ramal',
    'linea': 'RAMAL 1',
    'punto_referencia': 'KM 1',
    'estado_linea': 'Operativa',
    'observaciones': 'Sin novedad',
    'created_at': DateTime(2026, 7, 31).toIso8601String(),
    'updated_at': DateTime(2026, 7, 31).toIso8601String(),
    'created_by': 'local',
    'updated_by': 'local',
    'device_id': 'device',
    'local_version': 1,
    'remote_version': 0,
    'sync_status': 'pendingCreate',
    'deleted_at': null,
  };
}

Map<String, Object?> _findingPayload(String id, String inspectionId) {
  return {
    'global_id': id,
    'inspection_id': inspectionId,
    'tipo': 'Fuga',
    'detalle': 'Leve',
    'descripcion': 'Hallazgo',
    'latitud': '1',
    'longitud': '2',
    'created_at': DateTime(2026, 7, 31).toIso8601String(),
    'updated_at': DateTime(2026, 7, 31).toIso8601String(),
    'created_by': 'local',
    'updated_by': 'local',
    'device_id': 'device',
    'local_version': 1,
    'remote_version': 0,
    'deleted_at': null,
  };
}

Map<String, Object?> _remoteInspection(
  String id, {
  String responsable = 'Remoto',
  DateTime? updatedAt,
  int remoteVersion = 1,
}) {
  final timestamp = updatedAt ?? DateTime(2026, 7, 31, 10);
  return {
    'global_id': id,
    'fecha': Timestamp.fromDate(timestamp),
    'responsable': responsable,
    'tipo_linea': 'Ramal',
    'linea': 'RAMAL 1',
    'punto_referencia': 'KM 1',
    'estado_linea': 'Operativa',
    'observacion_general': 'Remota',
    'created_at': Timestamp.fromDate(timestamp),
    'updated_at': Timestamp.fromDate(timestamp),
    'created_by': 'remote',
    'updated_by': 'remote',
    'device_id': 'remote-device',
    'local_version': 1,
    'remote_version': remoteVersion,
    'sync_status': 'synced',
    'deleted_at': null,
  };
}

Map<String, Object?> _remoteFinding(String id, String inspectionId) {
  final timestamp = DateTime(2026, 7, 31, 10);
  return {
    'global_id': id,
    'inspection_global_id': inspectionId,
    'categoria': 'Fuga',
    'subcategoria': 'Leve',
    'descripcion': 'Hallazgo remoto',
    'latitud': '1',
    'longitud': '2',
    'created_at': Timestamp.fromDate(timestamp),
    'updated_at': Timestamp.fromDate(timestamp),
    'created_by': 'remote',
    'updated_by': 'remote',
    'device_id': 'remote-device',
    'local_version': 1,
    'remote_version': 1,
    'deleted_at': null,
  };
}

Future<void> _insertInspection(
  LinerbDatabase database, {
  required String id,
  required String responsable,
  required DateTime updatedAt,
  required int remoteVersion,
  required SyncStatus syncStatus,
}) async {
  final db = await database.open();
  await db.insert('inspections', {
    'id': id,
    'linea': 'RAMAL 1',
    'tipo_linea': 'Ramal',
    'responsable': responsable,
    'fecha_iso': DateTime(2026, 7, 31).toIso8601String(),
    'estado_linea': 'Operativa',
    'punto_referencia': 'KM 1',
    'observaciones': 'Local',
    'source': 'test',
    'source_key': null,
    'created_order': 0,
    'is_invalid': 0,
    'diagnostic_notes': null,
    'global_id': id,
    'created_at': DateTime(2026, 7, 31, 9).toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'created_by': 'local',
    'updated_by': 'local',
    'device_id': 'device',
    'local_version': 1,
    'remote_version': remoteVersion,
    'sync_status': syncStatusToStorage(syncStatus),
    'last_sync_at': null,
    'deleted_at': null,
  });
}

Future<Map<String, Object?>> _singleInspection(LinerbDatabase database) async {
  final db = await database.open();
  return (await db.query('inspections')).single;
}
