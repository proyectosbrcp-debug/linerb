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
  final String category;

  const DashboardFindingRecord({required this.id, required this.category});
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
    final rows = await db.query(
      'hallazgos',
      where: 'is_invalid = ? AND inspection_id IS NOT NULL',
      whereArgs: [0],
    );

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
    );
  }

  Future<int> _countInvalid(Database db, String table) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $table WHERE is_invalid = 1',
    );
    return result.single['total'] as int;
  }
}
