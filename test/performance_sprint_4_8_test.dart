import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/controllers/dashboard_controller.dart';
import 'package:linerb/core/constants/query_page_config.dart';
import 'package:linerb/core/constants/sync_batch_config.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/models/sync_models.dart';
import 'package:linerb/repositories/dashboard_repository.dart';
import 'package:linerb/repositories/catalog_repository.dart';
import 'package:linerb/repositories/sync_repository.dart';
import 'package:linerb/services/sync_worker.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_database_storage.dart';
import 'package:linerb/storage/sync_metadata_storage.dart';
import 'package:linerb/storage/sync_queue_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LinerbDatabase database;
  late LocalDatabaseStorage storage;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    storage = LocalDatabaseStorage(database: database, inspeccionesMemoria: []);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'Sprint 4.8 crea indices SQLite versionados para consultas criticas',
    () async {
      final db = await database.open();

      expect(LinerbDatabase.version, 4);
      expect(await _indexExists(db, 'idx_inspections_history_cursor'), isTrue);
      expect(await _indexExists(db, 'idx_inspections_valid_fecha'), isTrue);
      expect(
        await _indexExists(db, 'idx_inspections_updated_at_global_id'),
        isTrue,
      );
      expect(await _indexExists(db, 'idx_hallazgos_valid_inspection'), isTrue);
      expect(
        await _indexExists(db, 'idx_hallazgos_updated_at_global_id'),
        isTrue,
      );
      expect(await _indexExists(db, 'idx_sync_queue_due'), isTrue);
    },
  );

  test('historial pagina por cursor estable y fecha descendente', () async {
    for (var index = 0; index < 35; index++) {
      await storage.agregarInspeccionCompleta(
        _inspection(index, DateTime(2026, 1, 1).add(Duration(days: index))),
        const [],
      );
    }

    final first = await storage.cargarHistorialPage(limit: 10);
    final second = await storage.cargarHistorialPage(
      cursor: first.nextCursor,
      limit: 10,
    );

    expect(first.items, hasLength(10));
    expect(second.items, hasLength(10));
    expect(first.hasMore, isTrue);
    expect(first.items.first.fecha, DateTime(2026, 2, 4));
    expect(first.items.last.fecha.isAfter(second.items.first.fecha), isTrue);
    expect(
      first.items
          .map((item) => item.linea)
          .toSet()
          .intersection(second.items.map((item) => item.linea).toSet()),
      isEmpty,
    );
  });

  test(
    'detalle de hallazgos pagina sin duplicados y conserva totales',
    () async {
      for (var index = 0; index < 120; index++) {
        await storage.agregarInspeccionCompleta(
          _inspection(index, DateTime(2026, 1, 1).add(Duration(days: index))),
          [
            HallazgoInspeccion(
              tipo: 'Fuga',
              detalle: '',
              latitud: '1',
              longitud: '2',
              descripcion: 'Hallazgo',
            ),
          ],
        );
      }
      final controller = DashboardController(
        repository: SqliteDashboardRepository(
          database: database,
          catalogRepository: _CatalogRepository(),
        ),
        clock: () => DateTime(2026, 7, 31),
      );

      final first = await controller.loadFindingsDetail(
        limit: QueryPageConfig.dashboardFindingsPageSize,
      );
      final second = await controller.loadFindingsDetail(
        cursor: first.nextCursor,
        limit: QueryPageConfig.dashboardFindingsPageSize,
      );

      expect(first.total, 120);
      expect(first.items, hasLength(QueryPageConfig.dashboardFindingsPageSize));
      expect(first.hasMore, isTrue);
      expect(
        first.items
            .map((item) => item.id)
            .toSet()
            .intersection(second.items.map((item) => item.id).toSet()),
        isEmpty,
      );
    },
  );

  test(
    'dashboard reutiliza cache mientras no cambia la revision local',
    () async {
      final repository = _CountingDashboardRepository();
      final controller = DashboardController(
        repository: repository,
        clock: () => DateTime(2026, 7, 31),
      );

      await controller.loadSummary();
      await controller.loadSummary();
      repository.revision++;
      await controller.loadSummary();

      expect(repository.inspectionLoads, 2);
      expect(repository.findingLoads, 2);
    },
  );

  test('sync worker procesa cola grande por paginas configuradas', () async {
    final queue = _PagedQueue();
    for (var index = 0; index < 1000; index++) {
      queue.entries.add(_entry('inspection-$index'));
    }
    final remote = _Remote();
    final worker = SyncWorker(
      queueStorage: queue,
      metadataStorage: _Metadata(),
      remoteDataSource: remote,
    );

    final result = await worker.syncNow();

    expect(result.status, SyncWorkerStatus.synced);
    expect(result.processed, 1000);
    expect(queue.entries, isEmpty);
    expect(queue.pageRequests, greaterThanOrEqualTo(10));
    expect(queue.requestedLimits.toSet(), {SyncBatchConfig.pushBatchSize});
  });
}

Future<bool> _indexExists(dynamic db, String name) async {
  final rows = await db.query(
    'sqlite_master',
    where: 'type = ? AND name = ?',
    whereArgs: ['index', name],
  );
  return rows.isNotEmpty;
}

Inspeccion _inspection(int index, DateTime date) {
  return Inspeccion(
    linea: 'RAMAL $index',
    tipoLinea: 'Ramal',
    responsable: 'Operador',
    fecha: date,
    estadoLinea: 'Operativa',
    puntoReferencia: 'KM $index',
    observaciones: 'Obs',
  );
}

class _CatalogRepository implements CatalogRepository {
  @override
  Future<CatalogData> cargarCatalogos() async {
    return CatalogData(
      troncalesJson: const {},
      ramalesJson: List.generate(120, (index) => 'RAMAL $index'),
    );
  }
}

class _CountingDashboardRepository extends DashboardRepository {
  int revision = 1;
  int inspectionLoads = 0;
  int findingLoads = 0;

  @override
  Future<CatalogData?> loadCatalog() async {
    return const CatalogData(troncalesJson: {}, ramalesJson: ['RAMAL 1']);
  }

  @override
  Future<int> loadLocalRevision() async => revision;

  @override
  Future<List<DashboardInspectionRecord>> loadValidInspections() async {
    inspectionLoads++;
    return [
      DashboardInspectionRecord(
        id: 'i1',
        lineName: 'RAMAL 1',
        tipoLinea: 'Ramal',
        responsible: 'Operador',
        date: DateTime(2026, 7, 30),
      ),
    ];
  }

  @override
  Future<List<DashboardFindingRecord>> loadValidFindings() async {
    findingLoads++;
    return const [];
  }

  @override
  Future<int> countInvalidRecords() async => 0;
}

SyncQueueEntry _entry(String id) {
  return SyncQueueEntry(
    id: 'queue-$id',
    entityType: SyncEntityType.inspection,
    entityId: id,
    operation: SyncOperationType.create,
    payloadJson: jsonEncode({'remote_version': 0}),
    attempts: 0,
    nextAttemptAt: null,
    lastError: null,
    createdAt: DateTime(2026, 7, 31),
    updatedAt: DateTime(2026, 7, 31),
  );
}

class _PagedQueue implements SyncQueueStorage {
  final entries = <SyncQueueEntry>[];
  int pageRequests = 0;
  final requestedLimits = <int>[];

  @override
  Future<void> enqueue(SyncQueueOperation operation) async {}

  @override
  Future<bool> hasDuplicate(SyncQueueOperation operation) async => false;

  @override
  Future<void> incrementAttempts(String queueEntryId) async {}

  @override
  Future<void> markCompleted(String queueEntryId) async {
    entries.removeWhere((entry) => entry.id == queueEntryId);
  }

  @override
  Future<List<SyncQueueEntry>> pendingOperations() async => List.of(entries);

  @override
  Future<List<SyncQueueEntry>> pendingOperationsPage({
    required DateTime now,
    int limit = 100,
  }) async {
    pageRequests++;
    requestedLimits.add(limit);
    return entries.take(limit).toList();
  }

  @override
  Future<void> registerFailure(String queueEntryId, String error) async {}

  @override
  Future<void> rescheduleRetry(
    String queueEntryId,
    DateTime nextAttemptAt,
  ) async {}
}

class _Metadata implements SyncMetadataStorage {
  @override
  Future<SyncMetadata?> loadMetadata(
    SyncEntityType entityType,
    String entityId,
  ) async {
    return null;
  }

  @override
  Future<void> markConflict(
    SyncEntityType entityType,
    String entityId, {
    required String remotePayload,
  }) async {}

  @override
  Future<void> markSynced(
    SyncEntityType entityType,
    String entityId, {
    required int remoteVersion,
    required DateTime lastSyncAt,
  }) async {}

  @override
  Future<void> updateStatus(
    SyncEntityType entityType,
    String entityId,
    SyncStatus status,
  ) async {}
}

class _Remote implements RemoteSyncDataSource {
  @override
  Future<void> push(SyncQueueEntry operation) async {}

  @override
  Future<void> pushBatch(List<SyncQueueEntry> operations) async {}

  @override
  Future<void> createFinding(Map<String, Object?> payload) async {}

  @override
  Future<void> createInspection(Map<String, Object?> payload) async {}

  @override
  Future<void> deleteFinding(Map<String, Object?> payload) async {}

  @override
  Future<void> deleteInspection(Map<String, Object?> payload) async {}

  @override
  Future<RemoteChangeSet> fetchChanges({
    DateTime? since,
    RemoteSyncCursors? cursors,
  }) async {
    return const RemoteChangeSet(inspections: [], findings: [], cursor: null);
  }

  @override
  Future<List<Map<String, Object?>>> fetchFindingsForInspections(
    List<String> inspectionGlobalIds,
  ) async {
    return const [];
  }

  @override
  Future<void> updateFinding(Map<String, Object?> payload) async {}

  @override
  Future<void> updateInspection(Map<String, Object?> payload) async {}
}
