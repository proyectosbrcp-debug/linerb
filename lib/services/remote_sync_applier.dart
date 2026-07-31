import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:sqflite/sqflite.dart';

import '../models/sync_models.dart';
import '../storage/local/linerb_database.dart';

class RemoteSyncApplier {
  static const String cursorKey = 'remote_sync_cursor';
  static const String inspectionsCursorKey = 'remote_sync_cursor_inspections';
  static const String findingsCursorKey = 'remote_sync_cursor_findings';
  static const Duration clockSkewTolerance = Duration(minutes: 5);

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
      await _saveCursor(txn, inspectionsCursorKey, changeSet.inspectionsCursor);
      await _saveCursor(txn, findingsCursorKey, changeSet.findingsCursor);
      await _saveLegacyCursor(txn, changeSet.cursor);
    });
  }

  Future<RemoteSyncCursors> loadCursors() async {
    return RemoteSyncCursors(
      inspections: await loadCursorFor(SyncEntityType.inspection),
      findings: await loadCursorFor(SyncEntityType.finding),
    );
  }

  Future<SyncCursor?> loadCursorFor(SyncEntityType entityType) async {
    final db = await database.open();
    final rows = await db.query(
      'migration_metadata',
      where: 'key = ?',
      whereArgs: [_cursorKeyFor(entityType)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.single['value'];
    if (value is! String) return null;
    try {
      return SyncCursor.fromJson(
        Map<String, Object?>.from(jsonDecode(value) as Map),
      );
    } catch (_) {
      return null;
    }
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
    if (existing.isNotEmpty) {
      final decision = _resolveLastWriteWins(existing.single, remote);
      if (decision == _RemoteApplyDecision.keepLocal) return;
      if (decision == _RemoteApplyDecision.conflict) {
        await _markConflict(txn, 'inspections', globalId, remote);
        return;
      }
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
    if (existing.isNotEmpty) {
      final decision = _resolveLastWriteWins(existing.single, remote);
      if (decision == _RemoteApplyDecision.keepLocal) return;
      if (decision == _RemoteApplyDecision.conflict) {
        await _markConflict(txn, 'hallazgos', globalId, remote);
        return;
      }
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

  _RemoteApplyDecision _resolveLastWriteWins(
    Map<String, Object?> local,
    Map<String, Object?> remote,
  ) {
    final status = local['sync_status'] as String?;
    final hasPending =
        status == syncStatusToStorage(SyncStatus.pendingCreate) ||
        status == syncStatusToStorage(SyncStatus.pendingUpdate) ||
        status == syncStatusToStorage(SyncStatus.pendingDelete);
    if (!hasPending) return _RemoteApplyDecision.applyRemote;

    final localUpdatedAt = _parseLocalDate(local['updated_at']);
    final remoteUpdatedAt = _parseRemoteDate(remote['updated_at']);
    if (localUpdatedAt == null || remoteUpdatedAt == null) {
      return _RemoteApplyDecision.conflict;
    }

    final difference = localUpdatedAt.difference(remoteUpdatedAt).abs();
    if (difference > clockSkewTolerance) {
      return localUpdatedAt.isAfter(remoteUpdatedAt)
          ? _RemoteApplyDecision.keepLocal
          : _RemoteApplyDecision.applyRemote;
    }

    final remoteVersion = remote['remote_version'];
    final localRemoteVersion = local['remote_version'];
    if (remoteVersion is int && localRemoteVersion is int) {
      if (remoteVersion > localRemoteVersion) {
        return _RemoteApplyDecision.applyRemote;
      }
      if (remoteVersion < localRemoteVersion) {
        return _RemoteApplyDecision.keepLocal;
      }
    }

    final remoteGlobalId = remote['global_id'];
    final localGlobalId = local['global_id'];
    if (remoteGlobalId is String && localGlobalId is String) {
      return remoteGlobalId.compareTo(localGlobalId) >= 0
          ? _RemoteApplyDecision.applyRemote
          : _RemoteApplyDecision.keepLocal;
    }

    return _RemoteApplyDecision.conflict;
  }

  String _dateString(Object? value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is String && value.isNotEmpty) return value;
    return DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
  }

  DateTime? _parseRemoteDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _parseLocalDate(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  String? _nullableDateString(Object? value) {
    if (value == null) return null;
    return _dateString(value);
  }

  Future<void> _saveCursor(
    Transaction txn,
    String key,
    SyncCursor? cursor,
  ) async {
    if (cursor == null) return;
    await txn.insert('migration_metadata', {
      'key': key,
      'value': jsonEncode(cursor.toJson()),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _saveLegacyCursor(Transaction txn, DateTime? cursor) async {
    if (cursor == null) return;
    await txn.insert('migration_metadata', {
      'key': cursorKey,
      'value': cursor.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _cursorKeyFor(SyncEntityType entityType) {
    return switch (entityType) {
      SyncEntityType.inspection => inspectionsCursorKey,
      SyncEntityType.finding => findingsCursorKey,
    };
  }

  Future<void> _markConflict(
    Transaction txn,
    String table,
    String globalId,
    Map<String, Object?> remote,
  ) async {
    await txn.update(
      table,
      {
        'sync_status': syncStatusToStorage(SyncStatus.conflict),
        'diagnostic_notes': _safeRemoteEvidence(remote),
      },
      where: 'global_id = ?',
      whereArgs: [globalId],
    );
  }

  String _safeRemoteEvidence(Map<String, Object?> remote) {
    return jsonEncode({
      'global_id': remote['global_id'],
      'updated_at': _dateString(remote['updated_at']),
      'remote_version': remote['remote_version'],
      'deleted_at': _nullableDateString(remote['deleted_at']),
    });
  }
}

enum _RemoteApplyDecision { applyRemote, keepLocal, conflict }
