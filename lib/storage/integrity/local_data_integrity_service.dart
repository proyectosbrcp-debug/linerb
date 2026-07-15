import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/utils/stable_id.dart';
import '../local/linerb_database.dart';

class LocalIntegrityIssue {
  final String entityType;
  final String? entityId;
  final String issueType;
  final String evidence;

  const LocalIntegrityIssue({
    required this.entityType,
    required this.entityId,
    required this.issueType,
    required this.evidence,
  });
}

class LocalIntegrityReport {
  final DateTime validatedAt;
  final List<LocalIntegrityIssue> issues;

  const LocalIntegrityReport({required this.validatedAt, required this.issues});

  int get issueCount => issues.length;
}

class LocalDataIntegrityService {
  final LinerbDatabase database;

  const LocalDataIntegrityService({required this.database});

  Future<LocalIntegrityReport> validateAndMark() async {
    final db = await database.open();
    final validatedAt = DateTime.now();
    final issues = <LocalIntegrityIssue>[];

    issues.addAll(await _validateInspections(db));
    issues.addAll(await _validateHallazgos(db));
    issues.addAll(await _validateDraft(db));

    await db.insert('migration_metadata', {
      'key': 'last_integrity_validation',
      'value': validatedAt.toIso8601String(),
      'updated_at': validatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    for (final issue in issues) {
      await _recordIssue(db, issue, validatedAt);
      await _markInvalid(db, issue);
    }

    return LocalIntegrityReport(validatedAt: validatedAt, issues: issues);
  }

  Future<List<LocalIntegrityIssue>> _validateInspections(Database db) async {
    final issues = <LocalIntegrityIssue>[];
    final rows = await db.rawQuery('SELECT rowid, * FROM inspections');

    for (final row in rows) {
      final rowId = row['rowid']?.toString();
      final id = row['id'] as String?;
      final fecha = row['fecha_iso'] as String?;

      if (id == null || id.trim().isEmpty) {
        issues.add(_issue('inspection', rowId, 'inspection_missing_id', row));
      }

      if (_empty(row['linea']) ||
          _empty(row['tipo_linea']) ||
          _empty(row['responsable']) ||
          _empty(row['fecha_iso']) ||
          _empty(row['estado_linea']) ||
          _empty(row['source']) ||
          row['created_order'] == null) {
        issues.add(
          _issue('inspection', id ?? rowId, 'inspection_corrupt_fields', row),
        );
      }

      if (fecha != null && DateTime.tryParse(fecha) == null) {
        issues.add(
          _issue('inspection', id ?? rowId, 'inspection_invalid_date', row),
        );
      }
    }

    final duplicates = await db.rawQuery('''
SELECT linea, tipo_linea, responsable, fecha_iso, estado_linea, punto_referencia,
       observaciones, COUNT(*) AS total, GROUP_CONCAT(id) AS ids
FROM inspections
GROUP BY linea, tipo_linea, responsable, fecha_iso, estado_linea,
         punto_referencia, observaciones
HAVING total > 1
''');

    for (final row in duplicates) {
      issues.add(
        _issue(
          'inspection',
          row['ids']?.toString(),
          'inspection_duplicate',
          row,
        ),
      );
    }

    return issues;
  }

  Future<List<LocalIntegrityIssue>> _validateHallazgos(Database db) async {
    final issues = <LocalIntegrityIssue>[];
    final rows = await db.rawQuery('SELECT rowid, * FROM hallazgos');

    for (final row in rows) {
      final rowId = row['rowid']?.toString();
      final id = row['id'] as String?;
      final inspectionId = row['inspection_id'] as String?;
      final draftId = row['draft_id'] as String?;

      if (id == null || id.trim().isEmpty) {
        issues.add(_issue('hallazgo', rowId, 'hallazgo_missing_id', row));
      }

      if (_empty(row['tipo']) ||
          row['latitud'] == null ||
          row['longitud'] == null ||
          row['descripcion'] == null ||
          row['created_order'] == null) {
        issues.add(
          _issue('hallazgo', id ?? rowId, 'hallazgo_corrupt_fields', row),
        );
      }

      if ((inspectionId == null || inspectionId.isEmpty) &&
          (draftId == null || draftId.isEmpty)) {
        issues.add(
          _issue('hallazgo', id ?? rowId, 'hallazgo_without_owner', row),
        );
      }

      if (inspectionId != null && inspectionId.isNotEmpty) {
        final parent = await db.query(
          'inspections',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [inspectionId],
          limit: 1,
        );
        if (parent.isEmpty) {
          issues.add(_issue('hallazgo', id ?? rowId, 'hallazgo_orphan', row));
        }
      }
    }

    final duplicates = await db.rawQuery('''
SELECT tipo, detalle, latitud, longitud, descripcion, foto1_path, foto2_path,
       inspection_id, draft_id, COUNT(*) AS total, GROUP_CONCAT(id) AS ids
FROM hallazgos
GROUP BY tipo, detalle, latitud, longitud, descripcion, foto1_path, foto2_path,
         inspection_id, draft_id
HAVING total > 1
''');

    for (final row in duplicates) {
      issues.add(
        _issue('hallazgo', row['ids']?.toString(), 'hallazgo_duplicate', row),
      );
    }

    return issues;
  }

  Future<List<LocalIntegrityIssue>> _validateDraft(Database db) async {
    final issues = <LocalIntegrityIssue>[];
    final rows = await db.rawQuery('SELECT rowid, * FROM draft');

    for (final row in rows) {
      final id = row['id'] as String?;
      final rowId = row['rowid']?.toString();

      if (_empty(row['id']) ||
          _empty(row['usuario']) ||
          _empty(row['tipo_linea']) ||
          _empty(row['seleccion_linea']) ||
          _empty(row['estado_linea']) ||
          _empty(row['updated_at'])) {
        issues.add(_issue('draft', id ?? rowId, 'draft_incomplete', row));
      }
    }

    return issues;
  }

  LocalIntegrityIssue _issue(
    String entityType,
    String? entityId,
    String issueType,
    Map<String, Object?> evidence,
  ) {
    return LocalIntegrityIssue(
      entityType: entityType,
      entityId: entityId,
      issueType: issueType,
      evidence: jsonEncode(evidence),
    );
  }

  Future<void> _recordIssue(
    Database db,
    LocalIntegrityIssue issue,
    DateTime detectedAt,
  ) async {
    final id = StableId.fromParts('integrity', [
      issue.entityType,
      issue.entityId,
      issue.issueType,
      issue.evidence,
    ]);

    await db.insert('integrity_issues', {
      'id': id,
      'entity_type': issue.entityType,
      'entity_id': issue.entityId,
      'issue_type': issue.issueType,
      'evidence': issue.evidence,
      'detected_at': detectedAt.toIso8601String(),
      'resolution': 'marked',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _markInvalid(Database db, LocalIntegrityIssue issue) async {
    final table = switch (issue.entityType) {
      'inspection' => 'inspections',
      'hallazgo' => 'hallazgos',
      'draft' => 'draft',
      _ => null,
    };

    if (table == null || issue.entityId == null) return;

    final ids = issue.entityId!.split(',');
    for (final id in ids) {
      final updated = await db.update(
        table,
        {'is_invalid': 1, 'diagnostic_notes': issue.issueType},
        where: 'id = ?',
        whereArgs: [id],
      );
      final rowId = int.tryParse(id);
      if (updated == 0 && rowId != null) {
        await db.update(
          table,
          {'is_invalid': 1, 'diagnostic_notes': issue.issueType},
          where: 'rowid = ?',
          whereArgs: [rowId],
        );
      }
    }
  }

  bool _empty(Object? value) {
    return value == null || (value is String && value.trim().isEmpty);
  }
}
