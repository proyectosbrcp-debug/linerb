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

  const LocalDiagnosticSnapshot({
    required this.inspectionCount,
    required this.hallazgoCount,
    required this.integrityIssueCount,
    required this.migrationCompleted,
    required this.runtimeStatus,
    required this.lastInitializationError,
    required this.lastValidationAt,
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
    );
  }

  Future<int> _count(dynamic db, String table) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
    return result.single['total'] as int;
  }
}
