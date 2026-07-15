import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/time/app_clock.dart';
import '../../core/utils/stable_id.dart';
import '../../models/draft_data.dart';
import '../../models/hallazgo_inspeccion.dart';
import '../../models/inspeccion.dart';
import '../../models/sync_models.dart';
import '../../services/datos_app.dart';
import '../draft_storage.dart';
import '../inspection_storage.dart';
import '../migration/migration_target.dart';
import '../storage_exceptions.dart';
import 'linerb_database.dart';
import 'local_sync_queue_storage.dart';

class LocalDatabaseStorage
    implements InspectionStorage, DraftStorage, MigrationTarget {
  static const String currentDraftId = 'current';

  final LinerbDatabase database;
  final List<Inspeccion>? inspeccionesMemoria;
  final bool failWrites;
  final int? failOnHallazgoIndex;
  final bool failSyncQueueWrites;
  final Clock clock;
  final Future<String> Function()? deviceIdProvider;
  final LocalSyncQueueStorage? syncQueueStorage;

  LocalDatabaseStorage({
    required this.database,
    this.inspeccionesMemoria,
    this.failWrites = false,
    this.failOnHallazgoIndex,
    this.failSyncQueueWrites = false,
    this.clock = const SystemClock(),
    this.deviceIdProvider,
    this.syncQueueStorage,
  });

  List<Inspeccion> get _inspeccionesMemoria =>
      inspeccionesMemoria ?? DatosApp.inspecciones;

  @override
  List<Inspeccion> obtenerInspeccionesMemoria() {
    return _inspeccionesMemoria;
  }

  @override
  void agregarInspeccionMemoria(Inspeccion inspeccion) {
    _inspeccionesMemoria.add(inspeccion);
  }

  @override
  DateTime? ultimaInspeccionMemoria(String linea) {
    final registros = _inspeccionesMemoria
        .where((i) => i.linea == linea)
        .toList();

    if (registros.isEmpty) return null;

    registros.sort((a, b) => b.fecha.compareTo(a.fecha));
    return registros.first.fecha;
  }

  @override
  Future<List<Inspeccion>> cargarHistorial() async {
    try {
      final db = await database.open();
      final rows = await db.query('inspections', orderBy: 'created_order ASC');

      if (rows.isEmpty) {
        throw const StorageNotFoundException('No existen inspecciones locales');
      }

      return rows.map(_inspeccionDesdeRow).toList();
    } on StorageException {
      rethrow;
    } catch (e) {
      throw StorageReadException('No se pudo leer inspecciones locales', e);
    }
  }

  @override
  Future<void> agregarInspeccionHistorial(Inspeccion inspeccion) async {
    return agregarInspeccionCompleta(inspeccion, const []);
  }

  @override
  Future<void> agregarInspeccionCompleta(
    Inspeccion inspeccion,
    List<HallazgoInspeccion> hallazgos,
  ) async {
    if (failWrites) {
      throw const StorageWriteException('Fallo simulado de escritura local');
    }

    try {
      final db = await database.open();
      final createdOrder = await _nextInspectionOrder();
      final now = clock.now();
      final nowIso = now.toIso8601String();
      final deviceId = await _deviceId();
      const userId = 'local_user';
      final id = StableId.fromParts('db_inspection', [
        inspeccion.linea,
        inspeccion.tipoLinea,
        inspeccion.responsable,
        inspeccion.fecha.toIso8601String(),
        inspeccion.estadoLinea,
        inspeccion.puntoReferencia,
        inspeccion.observaciones,
      ]);
      final queue =
          syncQueueStorage ??
          LocalSyncQueueStorage(
            database: database,
            clock: clock,
            failWrites: failSyncQueueWrites,
          );

      await db.transaction((txn) async {
        final inspectionRow = {
          'id': id,
          'linea': inspeccion.linea,
          'tipo_linea': inspeccion.tipoLinea,
          'responsable': inspeccion.responsable,
          'fecha_iso': inspeccion.fecha.toIso8601String(),
          'estado_linea': inspeccion.estadoLinea,
          'punto_referencia': inspeccion.puntoReferencia,
          'observaciones': inspeccion.observaciones,
          'source': 'app',
          'source_key': null,
          'created_order': createdOrder,
          'global_id': id,
          'created_at': nowIso,
          'updated_at': nowIso,
          'created_by': userId,
          'updated_by': userId,
          'device_id': deviceId,
          'local_version': 1,
          'remote_version': 0,
          'sync_status': syncStatusToStorage(SyncStatus.pendingCreate),
          'last_sync_at': null,
          'deleted_at': null,
        };
        final inserted = await txn.insert(
          'inspections',
          inspectionRow,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        if (inserted != 0) {
          await queue.enqueueInTransaction(
            txn,
            SyncQueueOperation(
              entityType: SyncEntityType.inspection,
              entityId: id,
              operation: SyncOperationType.create,
              payloadJson: _inspectionPayloadJson(inspectionRow),
            ),
          );

          for (var index = 0; index < hallazgos.length; index++) {
            if (failOnHallazgoIndex == index) {
              throw const StorageWriteException(
                'Fallo simulado guardando hallazgo local',
              );
            }
            final hallazgoRow = _hallazgoToRow(
              hallazgos[index],
              index,
              inspectionId: id,
              nowIso: nowIso,
              userId: userId,
              deviceId: deviceId,
              syncStatus: SyncStatus.pendingCreate,
            );
            await txn.insert(
              'hallazgos',
              hallazgoRow,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            await queue.enqueueInTransaction(
              txn,
              SyncQueueOperation(
                entityType: SyncEntityType.finding,
                entityId: hallazgoRow['id'] as String,
                operation: SyncOperationType.create,
                payloadJson: _hallazgoPayloadJson(hallazgoRow),
              ),
            );
          }
        }
      });
    } catch (e) {
      throw StorageWriteException('No se pudo guardar inspección local', e);
    }
  }

  @override
  Future<void> guardarBorrador(DraftData borrador) async {
    if (failWrites) {
      throw const StorageWriteException('Fallo simulado de escritura local');
    }

    try {
      final db = await database.open();

      await db.transaction((txn) async {
        await txn.delete(
          'hallazgos',
          where: 'draft_id = ?',
          whereArgs: [currentDraftId],
        );
        await txn.delete('draft', where: 'id = ?', whereArgs: [currentDraftId]);

        await txn.insert('draft', {
          'id': currentDraftId,
          'usuario': borrador.usuario,
          'tipo_linea': borrador.tipoLinea,
          'seleccion_linea': borrador.seleccionLinea,
          'responsable': borrador.responsable,
          'punto_referencia': borrador.puntoReferencia,
          'estado_linea': borrador.estadoLinea,
          'updated_at': DateTime.now().toIso8601String(),
        });

        for (var index = 0; index < borrador.hallazgos.length; index++) {
          await txn.insert(
            'hallazgos',
            _hallazgoToRow(
              borrador.hallazgos[index],
              index,
              draftId: currentDraftId,
            ),
          );
        }
      });
    } catch (e) {
      throw StorageWriteException('No se pudo guardar borrador local', e);
    }
  }

  @override
  Future<DraftData> cargarBorrador(String seleccionLinea) async {
    try {
      final db = await database.open();
      final draftRows = await db.query(
        'draft',
        where: 'id = ? AND seleccion_linea = ?',
        whereArgs: [currentDraftId, seleccionLinea],
        limit: 1,
      );

      if (draftRows.isEmpty) {
        throw const StorageNotFoundException('No existe borrador local');
      }

      final hallazgoRows = await db.query(
        'hallazgos',
        where: 'draft_id = ?',
        whereArgs: [currentDraftId],
        orderBy: 'created_order ASC',
      );

      final draft = draftRows.single;

      return DraftData(
        usuario: draft['usuario'] as String,
        tipoLinea: draft['tipo_linea'] as String,
        seleccionLinea: draft['seleccion_linea'] as String,
        responsable: draft['responsable'] as String,
        puntoReferencia: draft['punto_referencia'] as String,
        estadoLinea: draft['estado_linea'] as String,
        hallazgos: hallazgoRows.map(_hallazgoDesdeRow).toList(),
      );
    } on StorageException {
      rethrow;
    } catch (e) {
      throw StorageReadException('No se pudo leer borrador local', e);
    }
  }

  @override
  Future<void> borrarBorrador() async {
    if (failWrites) {
      throw const StorageWriteException('Fallo simulado de escritura local');
    }

    try {
      final db = await database.open();

      await db.transaction((txn) async {
        await txn.delete(
          'hallazgos',
          where: 'draft_id = ?',
          whereArgs: [currentDraftId],
        );
        await txn.delete('draft', where: 'id = ?', whereArgs: [currentDraftId]);
      });
    } catch (e) {
      throw StorageWriteException('No se pudo borrar borrador local', e);
    }
  }

  @override
  Future<bool> isMigrationCompleted(String key) async {
    final db = await database.open();
    final rows = await db.query(
      'migration_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    return rows.isNotEmpty && rows.single['value'] == 'completed';
  }

  @override
  Future<void> markMigrationCompleted(String key) async {
    final db = await database.open();
    await db.insert('migration_metadata', {
      'key': key,
      'value': 'completed',
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> saveLegacyInspection({
    required String id,
    required String sourceKey,
    required int createdOrder,
    required Inspeccion inspeccion,
  }) async {
    if (failWrites) {
      throw const StorageWriteException('Fallo simulado de migración');
    }

    final db = await database.open();
    const legacyTimestamp = '1970-01-01T00:00:00.000';
    final inserted = await db.insert('inspections', {
      'id': id,
      'linea': inspeccion.linea,
      'tipo_linea': inspeccion.tipoLinea,
      'responsable': inspeccion.responsable,
      'fecha_iso': inspeccion.fecha.toIso8601String(),
      'estado_linea': inspeccion.estadoLinea,
      'punto_referencia': inspeccion.puntoReferencia,
      'observaciones': inspeccion.observaciones,
      'source': 'v1_shared_preferences',
      'source_key': sourceKey,
      'created_order': createdOrder,
      'global_id': id,
      'created_at': legacyTimestamp,
      'updated_at': legacyTimestamp,
      'created_by': 'legacy',
      'updated_by': 'legacy',
      'device_id': 'legacy_device',
      'local_version': 1,
      'remote_version': 0,
      'sync_status': syncStatusToStorage(SyncStatus.synced),
      'last_sync_at': null,
      'deleted_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    return inserted != 0;
  }

  @override
  Future<void> saveMigratedDraft(DraftData draft) {
    return guardarBorrador(draft);
  }

  Future<int> inspectionCount() async {
    final db = await database.open();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM inspections',
    );
    return result.single['total'] as int;
  }

  Future<int> hallazgoCount() async {
    final db = await database.open();
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM hallazgos');
    return result.single['total'] as int;
  }

  Future<int> hallazgoCountForInspection(String linea) async {
    final db = await database.open();
    final result = await db.rawQuery(
      '''
SELECT COUNT(h.id) AS total
FROM hallazgos h
INNER JOIN inspections i ON i.id = h.inspection_id
WHERE i.linea = ?
''',
      [linea],
    );
    return result.single['total'] as int;
  }

  Future<void> hydrateMemoryFromDatabase() async {
    try {
      final historial = await cargarHistorial();
      for (final inspeccion in historial) {
        if (!_containsInspection(inspeccion)) {
          _inspeccionesMemoria.add(inspeccion);
        }
      }
    } on StorageNotFoundException {
      // Sin historial local todavía.
    }
  }

  Future<int> _nextInspectionOrder() async {
    final db = await database.open();
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(created_order), -1) + 1 AS next_order FROM inspections',
    );
    return result.single['next_order'] as int;
  }

  Inspeccion _inspeccionDesdeRow(Map<String, Object?> row) {
    return Inspeccion(
      linea: row['linea'] as String,
      tipoLinea: row['tipo_linea'] as String,
      responsable: row['responsable'] as String,
      fecha: DateTime.parse(row['fecha_iso'] as String),
      estadoLinea: row['estado_linea'] as String,
      puntoReferencia: row['punto_referencia'] as String,
      observaciones: row['observaciones'] as String,
    );
  }

  Map<String, Object?> _hallazgoToRow(
    HallazgoInspeccion hallazgo,
    int index, {
    String? draftId,
    String? inspectionId,
    String? nowIso,
    String userId = 'local_user',
    String deviceId = 'local_device',
    SyncStatus syncStatus = SyncStatus.synced,
  }) {
    final id = StableId.fromParts('hallazgo', [
      draftId,
      inspectionId,
      index,
      hallazgo.tipo,
      hallazgo.detalle,
      hallazgo.latitud,
      hallazgo.longitud,
      hallazgo.descripcion,
      hallazgo.foto1Path,
      hallazgo.foto2Path,
    ]);
    final timestamp = nowIso ?? clock.now().toIso8601String();
    return {
      'id': id,
      'inspection_id': inspectionId,
      'draft_id': draftId,
      'tipo': hallazgo.tipo,
      'detalle': hallazgo.detalle,
      'latitud': hallazgo.latitud,
      'longitud': hallazgo.longitud,
      'descripcion': hallazgo.descripcion,
      'foto1_path': hallazgo.foto1Path,
      'foto2_path': hallazgo.foto2Path,
      'created_order': index,
      'global_id': id,
      'created_at': timestamp,
      'updated_at': timestamp,
      'created_by': userId,
      'updated_by': userId,
      'device_id': deviceId,
      'local_version': 1,
      'remote_version': 0,
      'sync_status': syncStatusToStorage(syncStatus),
      'last_sync_at': null,
      'deleted_at': null,
    };
  }

  Future<String> _deviceId() async {
    final provider = deviceIdProvider;
    if (provider == null) return 'local_device';
    return provider();
  }

  String _inspectionPayloadJson(Map<String, Object?> row) {
    return jsonEncode({
      'global_id': row['global_id'],
      'linea': row['linea'],
      'tipo_linea': row['tipo_linea'],
      'responsable': row['responsable'],
      'fecha_iso': row['fecha_iso'],
      'estado_linea': row['estado_linea'],
      'punto_referencia': row['punto_referencia'],
      'observaciones': row['observaciones'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
      'created_by': row['created_by'],
      'updated_by': row['updated_by'],
      'device_id': row['device_id'],
      'local_version': row['local_version'],
      'remote_version': row['remote_version'],
      'sync_status': row['sync_status'],
      'last_sync_at': row['last_sync_at'],
      'deleted_at': row['deleted_at'],
    });
  }

  String _hallazgoPayloadJson(Map<String, Object?> row) {
    return jsonEncode({
      'global_id': row['global_id'],
      'inspection_id': row['inspection_id'],
      'tipo': row['tipo'],
      'detalle': row['detalle'],
      'latitud': row['latitud'],
      'longitud': row['longitud'],
      'descripcion': row['descripcion'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
      'created_by': row['created_by'],
      'updated_by': row['updated_by'],
      'device_id': row['device_id'],
      'local_version': row['local_version'],
      'remote_version': row['remote_version'],
      'sync_status': row['sync_status'],
      'last_sync_at': row['last_sync_at'],
      'deleted_at': row['deleted_at'],
    });
  }

  HallazgoInspeccion _hallazgoDesdeRow(Map<String, Object?> row) {
    return HallazgoInspeccion(
      tipo: row['tipo'] as String,
      detalle: row['detalle'] as String,
      latitud: row['latitud'] as String,
      longitud: row['longitud'] as String,
      descripcion: row['descripcion'] as String,
      foto1Path: row['foto1_path'] as String?,
      foto2Path: row['foto2_path'] as String?,
    );
  }

  bool _containsInspection(Inspeccion inspeccion) {
    return _inspeccionesMemoria.any((item) {
      return item.linea == inspeccion.linea &&
          item.tipoLinea == inspeccion.tipoLinea &&
          item.responsable == inspeccion.responsable &&
          item.fecha == inspeccion.fecha &&
          item.estadoLinea == inspeccion.estadoLinea &&
          item.puntoReferencia == inspeccion.puntoReferencia &&
          item.observaciones == inspeccion.observaciones;
    });
  }
}
