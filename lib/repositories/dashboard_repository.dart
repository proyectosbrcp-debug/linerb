import 'package:sqflite/sqflite.dart';

import '../core/performance/performance_monitor.dart';
import '../repositories/catalog_repository.dart';
import '../storage/local/linerb_database.dart';

class DashboardInspectionRecord {
  final String id;
  final String lineName;
  final String tipoLinea;
  final String responsible;
  final DateTime date;

  const DashboardInspectionRecord({
    required this.id,
    required this.lineName,
    required this.tipoLinea,
    required this.responsible,
    required this.date,
  });
}

class DashboardFindingRecord {
  final String id;
  final String inspectionId;
  final String category;
  final String lineName;
  final String tipoLinea;
  final String responsible;
  final DateTime? date;
  final String description;

  const DashboardFindingRecord({
    required this.id,
    required this.category,
    this.inspectionId = '',
    this.lineName = '',
    this.tipoLinea = '',
    this.responsible = '',
    this.date,
    this.description = '',
  });
}

abstract class DashboardRepository {
  Future<CatalogData?> loadCatalog();

  Future<List<DashboardInspectionRecord>> loadValidInspections();

  Future<List<DashboardFindingRecord>> loadValidFindings();

  Future<int> countInvalidRecords();

  Future<int> loadLocalRevision() async => 0;

  Future<List<DashboardFindingRecord>> loadValidFindingsPage({
    String? cursor,
    int limit = 50,
  }) {
    return loadValidFindings();
  }

  Future<int> countValidFindings() async {
    return (await loadValidFindings()).length;
  }

  Future<List<FindingCategoryCount>> loadFindingCategoryCounts() async {
    final counts = <String, int>{};
    for (final finding in await loadValidFindings()) {
      final category = finding.category.trim().isEmpty
          ? 'Sin categorÃ­a'
          : finding.category.trim();
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts.entries
        .map((entry) => FindingCategoryCount(entry.key, entry.value))
        .toList()
      ..sort((a, b) => a.category.compareTo(b.category));
  }
}

class FindingCategoryCount {
  final String category;
  final int count;

  const FindingCategoryCount(this.category, this.count);
}

class SqliteDashboardRepository implements DashboardRepository {
  final LinerbDatabase database;
  final CatalogRepository catalogRepository;

  const SqliteDashboardRepository({
    required this.database,
    required this.catalogRepository,
  });

  @override
  Future<CatalogData?> loadCatalog() {
    return catalogRepository.cargarCatalogos();
  }

  @override
  Future<List<DashboardInspectionRecord>> loadValidInspections() async {
    return PerformanceMonitor.measure(
      'dashboard.load_valid_inspections',
      category: 'sqlite',
      action: () async {
        final db = await database.open();
        final rows = await db.query(
          'inspections',
          columns: ['id', 'linea', 'tipo_linea', 'responsable', 'fecha_iso'],
          where: 'is_invalid = ? AND deleted_at IS NULL',
          whereArgs: [0],
          orderBy: 'fecha_iso ASC',
        );

        return rows.map(_inspectionFromRow).toList();
      },
    );
  }

  @override
  Future<List<DashboardFindingRecord>> loadValidFindings() async {
    final db = await database.open();
    final rows = await db.rawQuery('''
SELECT
  h.id AS id,
  h.inspection_id AS inspection_id,
  h.tipo AS tipo,
  h.descripcion AS descripcion,
  i.linea AS linea,
  i.tipo_linea AS tipo_linea,
  i.responsable AS responsable,
  i.fecha_iso AS fecha_iso
FROM hallazgos h
INNER JOIN inspections i ON i.id = h.inspection_id
WHERE h.is_invalid = 0
  AND i.is_invalid = 0
  AND i.deleted_at IS NULL
  AND h.deleted_at IS NULL
ORDER BY i.fecha_iso DESC
''');

    return rows.map(_findingFromRow).toList();
  }

  @override
  Future<List<DashboardFindingRecord>> loadValidFindingsPage({
    String? cursor,
    int limit = 50,
  }) {
    return PerformanceMonitor.measure(
      'dashboard.load_findings_page',
      category: 'sqlite',
      recordCount: limit,
      action: () async {
        final db = await database.open();
        final safeLimit = limit < 1 ? 1 : limit;
        final parsedCursor = _FindingCursor.parse(cursor);
        final rows = await db.rawQuery(
          '''
SELECT
  h.id AS id,
  h.inspection_id AS inspection_id,
  h.tipo AS tipo,
  h.descripcion AS descripcion,
  i.linea AS linea,
  i.tipo_linea AS tipo_linea,
  i.responsable AS responsable,
  i.fecha_iso AS fecha_iso
FROM hallazgos h
INNER JOIN inspections i ON i.id = h.inspection_id
WHERE h.is_invalid = 0
  AND i.is_invalid = 0
  AND i.deleted_at IS NULL
  AND h.deleted_at IS NULL
  ${parsedCursor == null ? '' : 'AND (i.fecha_iso < ? OR (i.fecha_iso = ? AND h.global_id < ?))'}
ORDER BY i.fecha_iso DESC, h.global_id DESC
LIMIT ?
''',
          parsedCursor == null
              ? [safeLimit]
              : [
                  parsedCursor.fechaIso,
                  parsedCursor.fechaIso,
                  parsedCursor.globalId,
                  safeLimit,
                ],
        );

        return rows.map(_findingFromRow).toList();
      },
    );
  }

  @override
  Future<int> countInvalidRecords() async {
    final db = await database.open();
    final inspections = await _countInvalid(db, 'inspections');
    final hallazgos = await _countInvalid(db, 'hallazgos');
    final drafts = await _countInvalid(db, 'draft');
    return inspections + hallazgos + drafts;
  }

  @override
  Future<int> loadLocalRevision() async {
    final db = await database.open();
    final rows = await db.rawQuery('''
SELECT
  (SELECT COUNT(*) FROM inspections) AS inspections_count,
  (SELECT COUNT(*) FROM hallazgos) AS findings_count,
  (SELECT COALESCE(MAX(updated_at), '') FROM inspections) AS inspections_max,
  (SELECT COALESCE(MAX(updated_at), '') FROM hallazgos) AS findings_max
''');
    final row = rows.single;
    return Object.hash(
      row['inspections_count'],
      row['findings_count'],
      row['inspections_max'],
      row['findings_max'],
    );
  }

  @override
  Future<int> countValidFindings() async {
    final db = await database.open();
    final result = await db.rawQuery('''
SELECT COUNT(h.id) AS total
FROM hallazgos h
INNER JOIN inspections i ON i.id = h.inspection_id
WHERE h.is_invalid = 0
  AND i.is_invalid = 0
  AND i.deleted_at IS NULL
  AND h.deleted_at IS NULL
''');
    return result.single['total'] as int;
  }

  @override
  Future<List<FindingCategoryCount>> loadFindingCategoryCounts() async {
    final db = await database.open();
    final rows = await db.rawQuery('''
SELECT
  CASE WHEN TRIM(h.tipo) = '' THEN 'Sin categorÃ­a' ELSE TRIM(h.tipo) END
    AS category,
  COUNT(h.id) AS total
FROM hallazgos h
INNER JOIN inspections i ON i.id = h.inspection_id
WHERE h.is_invalid = 0
  AND i.is_invalid = 0
  AND i.deleted_at IS NULL
  AND h.deleted_at IS NULL
GROUP BY category
ORDER BY category ASC
''');

    return rows
        .map(
          (row) => FindingCategoryCount(
            row['category'] as String,
            row['total'] as int,
          ),
        )
        .toList();
  }

  DashboardInspectionRecord _inspectionFromRow(Map<String, Object?> row) {
    return DashboardInspectionRecord(
      id: row['id'] as String,
      lineName: row['linea'] as String,
      tipoLinea: row['tipo_linea'] as String,
      responsible: row['responsable'] as String,
      date: DateTime.parse(row['fecha_iso'] as String),
    );
  }

  DashboardFindingRecord _findingFromRow(Map<String, Object?> row) {
    return DashboardFindingRecord(
      id: row['id'] as String,
      category: row['tipo'] as String,
      inspectionId: row['inspection_id'] as String,
      lineName: row['linea'] as String,
      tipoLinea: row['tipo_linea'] as String,
      responsible: row['responsable'] as String,
      date: DateTime.parse(row['fecha_iso'] as String),
      description: row['descripcion'] as String,
    );
  }

  Future<int> _countInvalid(Database db, String table) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $table WHERE is_invalid = 1',
    );
    return result.single['total'] as int;
  }
}

class _FindingCursor {
  final String fechaIso;
  final String globalId;

  const _FindingCursor({required this.fechaIso, required this.globalId});

  static _FindingCursor? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    final separator = value.lastIndexOf('|');
    if (separator <= 0 || separator >= value.length - 1) return null;
    return _FindingCursor(
      fechaIso: value.substring(0, separator),
      globalId: value.substring(separator + 1),
    );
  }
}
