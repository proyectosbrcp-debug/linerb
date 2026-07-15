import 'package:sqflite/sqflite.dart';

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
    final db = await database.open();
    final rows = await db.query(
      'inspections',
      where: 'is_invalid = ?',
      whereArgs: [0],
      orderBy: 'fecha_iso ASC',
    );

    return rows.map(_inspectionFromRow).toList();
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
ORDER BY i.fecha_iso DESC
''');

    return rows.map(_findingFromRow).toList();
  }

  @override
  Future<int> countInvalidRecords() async {
    final db = await database.open();
    final inspections = await _countInvalid(db, 'inspections');
    final hallazgos = await _countInvalid(db, 'hallazgos');
    final drafts = await _countInvalid(db, 'draft');
    return inspections + hallazgos + drafts;
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
