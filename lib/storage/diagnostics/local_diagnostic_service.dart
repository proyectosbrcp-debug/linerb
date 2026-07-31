import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../core/runtime/app_runtime_initializer.dart';
import '../local/linerb_database.dart';

class LocalDiagnosticSnapshot {
  final int inspectionCount;
  final int hallazgoCount;
  final int integrityIssueCount;
  final bool migrationCompleted;
  final RuntimeInitializationStatus runtimeStatus;
  final Object? lastInitializationError;
  final DateTime? lastValidationAt;
  final int pendingSyncOperations;
  final int tombstoneCount;
  final int? sqliteFileSizeBytes;

  const LocalDiagnosticSnapshot({
    required this.inspectionCount,
    required this.hallazgoCount,
    required this.integrityIssueCount,
    required this.migrationCompleted,
    required this.runtimeStatus,
    required this.lastInitializationError,
    required this.lastValidationAt,
    this.pendingSyncOperations = 0,
    this.tombstoneCount = 0,
    this.sqliteFileSizeBytes,
  });
}

class LocalDiagnosticService {
  final LinerbDatabase database;
  final AppRuntimeInitializer runtimeInitializer;

  const LocalDiagnosticService({
    required this.database,
    required this.runtimeInitializer,
  });

  Future<LocalDiagnosticSnapshot> collect() async {
    final db = await database.open();
    final inspectionCount = await _count(db, 'inspections');
    final hallazgoCount = await _count(db, 'hallazgos');
    final integrityIssueCount = await _count(db, 'integrity_issues');
    final pendingSyncOperations = await _count(db, 'sync_queue');
    final tombstoneCount =
        await _countWhere(db, 'inspections', 'deleted_at IS NOT NULL') +
        await _countWhere(db, 'hallazgos', 'deleted_at IS NOT NULL');
    final migrationRows = await db.query(
      'migration_metadata',
      where: 'key = ?',
      whereArgs: ['v1_shared_preferences'],
      limit: 1,
    );
    final validationRows = await db.query(
      'migration_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['last_integrity_validation'],
      limit: 1,
    );

    return LocalDiagnosticSnapshot(
      inspectionCount: inspectionCount,
      hallazgoCount: hallazgoCount,
      integrityIssueCount: integrityIssueCount,
      migrationCompleted:
          migrationRows.isNotEmpty &&
          migrationRows.single['value'] == 'completed',
      runtimeStatus: runtimeInitializer.status,
      lastInitializationError: runtimeInitializer.lastError,
      lastValidationAt: validationRows.isEmpty
          ? null
          : DateTime.tryParse(validationRows.single['value'] as String),
      pendingSyncOperations: pendingSyncOperations,
      tombstoneCount: tombstoneCount,
      sqliteFileSizeBytes: await _sqliteFileSizeBytes(),
    );
  }

  Future<int> _count(dynamic db, String table) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
    return result.single['total'] as int;
  }

  Future<int> _countWhere(dynamic db, String table, String where) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $table WHERE $where',
    );
    return result.single['total'] as int;
  }

  Future<int?> _sqliteFileSizeBytes() async {
    final resolvedPath =
        database.databasePath ??
        path.join(await sqflite.getDatabasesPath(), LinerbDatabase.defaultName);
    final file = File(resolvedPath);
    if (!await file.exists()) return null;
    return file.length();
  }
}
