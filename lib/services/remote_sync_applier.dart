import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:sqflite/sqflite.dart';

import '../models/sync_models.dart';
import '../storage/local/linerb_database.dart';

class RemoteSyncApplier {
  static const String cursorKey = 'remote_sync_cursor';

  final LinerbDatabase database;

  const RemoteSyncApplier({required this.database});

  Future<void> apply(RemoteChangeSet changeSet) async {
    final db = await database.open();
    await db.transaction((txn) async {
      for (final inspection in changeSet.inspections) {
        await _upsertInspection(txn, inspection);
      }
      for (final finding in changeSet.findings) {
        await _upsertFinding(txn, finding);
      }
      final cursor = changeSet.cursor;
      if (cursor != null) {
        await txn.insert('migration_metadata', {
          'key': cursorKey,
          'value': cursor.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<DateTime?> loadCursor() async {
    final db = await database.open();
    final rows = await db.query(
      'migration_metadata',
      where: 'key = ?',
      whereArgs: [cursorKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.single['value'] as String);
  }

  Future<void> _upsertInspection(
    Transaction txn,
    Map<String, Object?> remote,
  ) async {
    final globalId = remote['global_id'] as String?;
    if (globalId == null || globalId.isEmpty) return;

    final existing = await txn.query(
      'inspections',
      where: 'global_id = ?',
      whereArgs: [globalId],
      limit: 1,
    );
    if (existing.isNotEmpty &&
        _hasLocalPendingConflict(existing.single, remote)) {
      await txn.update(
        'inspections',
        {
          'sync_status': syncStatusToStorage(SyncStatus.conflict),
          'diagnostic_notes': remote.toString(),
        },
        where: 'global_id = ?',
        whereArgs: [globalId],
      );
      return;
    }

    final row = {
      'id': globalId,
      'linea': remote['linea'] ?? '',
      'tipo_linea': remote['tipo_linea'] ?? '',
      'responsable': remote['responsable'] ?? '',
      'fecha_iso': _dateString(remote['fecha']),
      'estado_linea': remote['estado_linea'] ?? '',
      'punto_referencia': remote['punto_referencia'] ?? '',
      'observaciones': remote['observacion_general'] ?? '',
      'source': 'firestore',
      'source_key': null,
      'created_order': 0,
      'is_invalid': 0,
      'diagnostic_notes': null,
      'global_id': globalId,
      'created_at': _dateString(remote['created_at']),
      'updated_at': _dateString(remote['updated_at']),
      'created_by': remote['created_by'] ?? '',
      'updated_by': remote['updated_by'] ?? '',
      'device_id': remote['device_id'] ?? '',
      'local_version': remote['local_version'] ?? 0,
      'remote_version': remote['remote_version'] ?? 0,
      'sync_status': syncStatusToStorage(SyncStatus.synced),
      'last_sync_at': DateTime.now().toIso8601String(),
      'deleted_at': _nullableDateString(remote['deleted_at']),
    };

    await txn.insert(
      'inspections',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _upsertFinding(
    Transaction txn,
    Map<String, Object?> remote,
  ) async {
    final globalId = remote['global_id'] as String?;
    final inspectionGlobalId = remote['inspection_global_id'] as String?;
    if (globalId == null ||
        globalId.isEmpty ||
        inspectionGlobalId == null ||
        inspectionGlobalId.isEmpty) {
      return;
    }

    final existing = await txn.query(
      'hallazgos',
      where: 'global_id = ?',
      whereArgs: [globalId],
      limit: 1,
    );
    if (existing.isNotEmpty &&
        _hasLocalPendingConflict(existing.single, remote)) {
      await txn.update(
        'hallazgos',
        {
          'sync_status': syncStatusToStorage(SyncStatus.conflict),
          'diagnostic_notes': remote.toString(),
        },
        where: 'global_id = ?',
        whereArgs: [globalId],
      );
      return;
    }

    await txn.insert('hallazgos', {
      'id': globalId,
      'inspection_id': inspectionGlobalId,
      'draft_id': null,
      'tipo': remote['categoria'] ?? '',
      'detalle': remote['subcategoria'] ?? '',
      'latitud': remote['latitud'] ?? '',
      'longitud': remote['longitud'] ?? '',
      'descripcion': remote['descripcion'] ?? '',
      'foto1_path': null,
      'foto2_path': null,
      'created_order': 0,
      'is_invalid': 0,
      'diagnostic_notes': null,
      'global_id': globalId,
      'created_at': _dateString(remote['created_at']),
      'updated_at': _dateString(remote['updated_at']),
      'created_by': remote['created_by'] ?? '',
      'updated_by': remote['updated_by'] ?? '',
      'device_id': remote['device_id'] ?? '',
      'local_version': remote['local_version'] ?? 0,
      'remote_version': remote['remote_version'] ?? 0,
      'sync_status': syncStatusToStorage(SyncStatus.synced),
      'last_sync_at': DateTime.now().toIso8601String(),
      'deleted_at': _nullableDateString(remote['deleted_at']),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  bool _hasLocalPendingConflict(
    Map<String, Object?> local,
    Map<String, Object?> remote,
  ) {
    final status = local['sync_status'] as String?;
    final remoteVersion = remote['remote_version'];
    final localRemoteVersion = local['remote_version'];
    final hasPending =
        status == syncStatusToStorage(SyncStatus.pendingCreate) ||
        status == syncStatusToStorage(SyncStatus.pendingUpdate) ||
        status == syncStatusToStorage(SyncStatus.pendingDelete);

    return hasPending &&
        remoteVersion is int &&
        localRemoteVersion is int &&
        remoteVersion > localRemoteVersion;
  }

  String _dateString(Object? value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is String && value.isNotEmpty) return value;
    return DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
  }

  String? _nullableDateString(Object? value) {
    if (value == null) return null;
    return _dateString(value);
  }
}
