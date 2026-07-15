import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/core/time/app_clock.dart';
import 'package:linerb/models/draft_data.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/models/sync_models.dart';
import 'package:linerb/services/device_identity_service.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_database_storage.dart';
import 'package:linerb/storage/local/local_sync_queue_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LinerbDatabase database;
  late _FixedClock clock;
  late LocalSyncQueueStorage queueStorage;
  late LocalDatabaseStorage storage;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    clock = _FixedClock(DateTime(2026, 4, 1, 10));
    database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    queueStorage = LocalSyncQueueStorage(database: database, clock: clock);
    storage = LocalDatabaseStorage(
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

  test('ID global estable y device_id persistente por instalación', () async {
    SharedPreferences.setMockInitialValues({});
    final service = DeviceIdentityService(clock: clock.now);

    final first = await service.deviceId();
    final second = await service.deviceId();

    expect(first, startsWith('device_'));
    expect(second, first);

    await storage.agregarInspeccionCompleta(_inspection(), const []);
    final db = await database.open();
    final rows = await db.query('inspections', limit: 1);

    expect(rows.single['id'], rows.single['global_id']);
    expect(rows.single['device_id'], 'device-test');
  });

  test('crea pendingCreate para inspección y hallazgos', () async {
    await storage.agregarInspeccionCompleta(_inspection(), [
      _finding('/local/foto1.jpg', '/local/foto2.jpg'),
    ]);

    final queue = await queueStorage.pendingOperations();

    expect(queue, hasLength(2));
    expect(queue.first.operation, SyncOperationType.create);
    expect(
      queue.map((item) => item.entityType),
      containsAll([SyncEntityType.inspection, SyncEntityType.finding]),
    );
  });

  test(
    'compacta create + update conservando create con payload reciente',
    () async {
      await queueStorage.enqueue(
        const SyncQueueOperation(
          entityType: SyncEntityType.inspection,
          entityId: 'i1',
          operation: SyncOperationType.create,
          payloadJson: '{"version":1}',
        ),
      );

      await queueStorage.enqueue(
        const SyncQueueOperation(
          entityType: SyncEntityType.inspection,
          entityId: 'i1',
          operation: SyncOperationType.update,
          payloadJson: '{"version":2}',
        ),
      );

      final queue = await queueStorage.pendingOperations();

      expect(queue, hasLength(1));
      expect(queue.single.operation, SyncOperationType.create);
      expect(queue.single.payloadJson, '{"version":2}');
    },
  );

  test('compacta update + update en un solo update', () async {
    await queueStorage.enqueue(_operation('i1', SyncOperationType.update, 1));
    await queueStorage.enqueue(_operation('i1', SyncOperationType.update, 2));

    final queue = await queueStorage.pendingOperations();

    expect(queue, hasLength(1));
    expect(queue.single.operation, SyncOperationType.update);
    expect(queue.single.payloadJson, '{"version":2}');
  });

  test(
    'compacta create + delete eliminando operación remota pendiente',
    () async {
      await queueStorage.enqueue(_operation('i1', SyncOperationType.create, 1));
      await queueStorage.enqueue(_operation('i1', SyncOperationType.delete, 2));

      final queue = await queueStorage.pendingOperations();

      expect(queue, isEmpty);
    },
  );

  test('compacta update + delete en delete', () async {
    await queueStorage.enqueue(_operation('i1', SyncOperationType.update, 1));
    await queueStorage.enqueue(_operation('i1', SyncOperationType.delete, 2));

    final queue = await queueStorage.pendingOperations();

    expect(queue, hasLength(1));
    expect(queue.single.operation, SyncOperationType.delete);
  });

  test('detecta operación duplicada', () async {
    final operation = _operation('i1', SyncOperationType.update, 1);

    await queueStorage.enqueue(operation);

    expect(await queueStorage.hasDuplicate(operation), isTrue);
  });

  test('incrementa intentos y reprograma reintento', () async {
    await queueStorage.enqueue(_operation('i1', SyncOperationType.update, 1));
    final entry = (await queueStorage.pendingOperations()).single;
    final retryAt = DateTime(2026, 4, 1, 11);

    await queueStorage.incrementAttempts(entry.id);
    await queueStorage.rescheduleRetry(entry.id, retryAt);
    await queueStorage.registerFailure(entry.id, 'sin conexión');

    final updated = (await queueStorage.pendingOperations()).single;
    expect(updated.attempts, 1);
    expect(updated.nextAttemptAt, retryAt);
    expect(updated.lastError, 'sin conexión');
  });

  test('operación conflict no se compacta', () async {
    await queueStorage.enqueue(
      const SyncQueueOperation(
        entityType: SyncEntityType.inspection,
        entityId: 'i1',
        operation: SyncOperationType.update,
        payloadJson: '{"version":1}',
        isConflict: true,
      ),
    );
    await queueStorage.enqueue(_operation('i1', SyncOperationType.update, 2));

    final queue = await queueStorage.pendingOperations();

    expect(queue, hasLength(2));
  });

  test('rollback si falla la cola al finalizar inspección', () async {
    final failingQueue = LocalSyncQueueStorage(
      database: database,
      clock: clock,
      failWrites: true,
    );
    final failingStorage = LocalDatabaseStorage(
      database: database,
      inspeccionesMemoria: [],
      clock: clock,
      deviceIdProvider: () async => 'device-test',
      syncQueueStorage: failingQueue,
    );

    expect(
      failingStorage.agregarInspeccionCompleta(_inspection(), [_finding()]),
      throwsA(isA<Exception>()),
    );

    final db = await database.open();
    final inspections = await db.query('inspections');
    final queue = await db.query('sync_queue');
    expect(inspections, isEmpty);
    expect(queue, isEmpty);
  });

  test('borrador permanece local y no genera cola', () async {
    await storage.guardarBorrador(_draft());

    final queue = await queueStorage.pendingOperations();

    expect(queue, isEmpty);
  });

  test(
    'fotografías, rutas locales y PDF quedan excluidos del payload remoto',
    () async {
      await storage.agregarInspeccionCompleta(_inspection(), [
        _finding('/local/foto1.jpg', '/local/foto2.jpg'),
      ]);

      final queue = await queueStorage.pendingOperations();
      final payloads = queue.map((item) => jsonDecode(item.payloadJson));

      for (final payload in payloads) {
        expect(payload.toString(), isNot(contains('foto')));
        expect(payload.toString(), isNot(contains('/local/foto')));
        expect(payload.toString(), isNot(contains('base64')));
        expect(payload.toString(), isNot(contains('pdf')));
      }
    },
  );

  test('dashboard sigue independiente de fotografías', () async {
    await storage.agregarInspeccionCompleta(_inspection(), [
      _finding('/foto/no/existe1.jpg', '/foto/no/existe2.jpg'),
    ]);

    final db = await database.open();
    final rows = await db.query('inspections');

    expect(rows, hasLength(1));
  });

  test(
    'finalización válida no depende de sincronización de imágenes',
    () async {
      await storage.agregarInspeccionCompleta(_inspection(), [
        _finding('/foto/no/existe1.jpg', '/foto/no/existe2.jpg'),
      ]);

      expect(await storage.inspectionCount(), 1);
      expect(await storage.hallazgoCountForInspection('RAMAL 1'), 1);
    },
  );
}

SyncQueueOperation _operation(
  String entityId,
  SyncOperationType operation,
  int version,
) {
  return SyncQueueOperation(
    entityType: SyncEntityType.inspection,
    entityId: entityId,
    operation: operation,
    payloadJson: '{"version":$version}',
  );
}

Inspeccion _inspection() {
  return Inspeccion(
    linea: 'RAMAL 1',
    tipoLinea: 'Ramal',
    responsable: 'Operador',
    fecha: DateTime(2026, 4, 1),
    estadoLinea: 'Operativa',
    puntoReferencia: 'KM 1',
    observaciones: 'Sin novedad',
  );
}

HallazgoInspeccion _finding([String? foto1Path, String? foto2Path]) {
  return HallazgoInspeccion(
    tipo: 'Fuga',
    detalle: 'Detalle',
    latitud: '1',
    longitud: '2',
    descripcion: 'Hallazgo',
    foto1Path: foto1Path,
    foto2Path: foto2Path,
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
    hallazgos: [_finding('/local/foto1.jpg', '/local/foto2.jpg')],
  );
}

class _FixedClock implements Clock {
  DateTime value;

  _FixedClock(this.value);

  @override
  DateTime now() => value;
}
