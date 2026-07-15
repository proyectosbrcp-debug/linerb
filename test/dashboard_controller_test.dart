import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/controllers/dashboard_controller.dart';
import 'package:linerb/core/domain/line_identity.dart';
import 'package:linerb/core/domain/line_semaforo.dart';
import 'package:linerb/models/dashboard_models.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/repositories/catalog_repository.dart';
import 'package:linerb/repositories/dashboard_repository.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_database_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LinerbDatabase database;
  late LocalDatabaseStorage storage;
  late FakeCatalogRepository catalogRepository;
  late DashboardController controller;
  final now = DateTime(2026, 3, 1);

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    storage = LocalDatabaseStorage(database: database, inspeccionesMemoria: []);
    catalogRepository = FakeCatalogRepository(_catalog());
    controller = DashboardController(
      repository: SqliteDashboardRepository(
        database: database,
        catalogRepository: catalogRepository,
      ),
      clock: () => now,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('catálogo vacío no divide por cero', () async {
    catalogRepository.catalog = const CatalogData(
      troncalesJson: {},
      ramalesJson: [],
    );

    final summary = await controller.loadSummary();

    expect(summary.totalCatalogLines, 0);
    expect(summary.coveragePercentage, 0);
    expect(summary.inspectedLines, 0);
  });

  test('historial vacío marca líneas como nunca inspeccionadas', () async {
    final summary = await controller.loadSummary();

    expect(summary.totalCatalogLines, 4);
    expect(summary.inspectedLines, 0);
    expect(summary.neverInspectedLines, 4);
    expect(summary.redLines, 4);
  });

  test('varias inspecciones de una misma línea usan la última fecha', () async {
    await _saveInspection(
      storage,
      line: ' troncal 1/sub 1 ',
      date: DateTime(2026, 1, 1),
    );
    await _saveInspection(
      storage,
      line: 'TRONCAL 1 / SUB 1',
      date: DateTime(2026, 2, 20),
    );

    final summary = await controller.loadSummary();
    final line = summary.lineStatuses.firstWhere(
      (item) => item.normalizedKey == 'TRONCAL 1 / SUB 1',
    );

    expect(line.inspectionCount, 2);
    expect(line.lastInspectionDate, DateTime(2026, 2, 20));
    expect(summary.inspectedLines, 1);
  });

  test('límites exactos del semáforo se conservan', () async {
    await _saveInspection(
      storage,
      line: 'RAMAL 1',
      date: DateTime(2026, 2, 14),
    );
    await _saveInspection(
      storage,
      line: 'RAMAL 2',
      date: DateTime(2026, 2, 13),
    );
    await _saveInspection(
      storage,
      line: 'TRONCAL 1 / SUB 1',
      date: DateTime(2025, 12, 30),
    );

    final summary = await controller.loadSummary();

    expect(
      _status(summary, 'RAMAL 1').semaforoStatus,
      LineSemaforoStatus.verde,
    );
    expect(
      _status(summary, 'RAMAL 2').semaforoStatus,
      LineSemaforoStatus.amarillo,
    );
    expect(
      _status(summary, 'TRONCAL 1 / SUB 1').semaforoStatus,
      LineSemaforoStatus.rojo,
    );
  });

  test('normaliza nombres y distingue tipos de línea', () async {
    await _saveInspection(storage, line: ' ramal   1 ', tipoLinea: 'Ramal');
    await _saveInspection(
      storage,
      line: 'troncal 1 / sub 1',
      tipoLinea: 'Troncal',
    );

    final summary = await controller.loadSummary();

    expect(_status(summary, 'RAMAL 1').kind, LineKind.ramal);
    expect(_status(summary, 'TRONCAL 1 / SUB 1').kind, LineKind.subtroncal);
    expect(summary.inspectedLines, 2);
  });

  test('agrupa inspecciones por responsable', () async {
    await _saveInspection(storage, line: 'RAMAL 1', responsible: 'Ana');
    await _saveInspection(storage, line: 'RAMAL 2', responsible: 'Ana');
    await _saveInspection(
      storage,
      line: 'TRONCAL 1 / SUB 1',
      responsible: 'Luis',
    );

    final summary = await controller.loadSummary();

    expect(
      summary.inspectionsByResponsible
          .firstWhere((item) => item.responsible == 'Ana')
          .count,
      2,
    );
    expect(
      summary.inspectionsByResponsible
          .firstWhere((item) => item.responsible == 'Luis')
          .count,
      1,
    );
  });

  test('agrupa hallazgos por categoría', () async {
    await _saveInspection(storage, line: 'RAMAL 1', findings: ['Fuga', 'Fuga']);
    await _saveInspection(storage, line: 'RAMAL 2', findings: ['Vegetación']);

    final summary = await controller.loadSummary();

    expect(
      summary.findingsByCategory
          .firstWhere((item) => item.category == 'Fuga')
          .count,
      2,
    );
    expect(
      summary.findingsByCategory
          .firstWhere((item) => item.category == 'Vegetación')
          .count,
      1,
    );
  });

  test('excluye registros inválidos de indicadores principales', () async {
    await _saveInspection(storage, line: 'RAMAL 1', findings: ['Fuga']);
    await _saveInspection(storage, line: 'RAMAL 2', findings: ['Fuga']);

    final db = await database.open();
    await db.update(
      'inspections',
      {'is_invalid': 1},
      where: 'linea = ?',
      whereArgs: ['RAMAL 2'],
    );
    final invalidFinding = await db.query(
      'hallazgos',
      columns: ['id'],
      where: 'tipo = ?',
      whereArgs: ['Fuga'],
      limit: 1,
    );
    await db.update(
      'hallazgos',
      {'is_invalid': 1},
      where: 'id = ?',
      whereArgs: [invalidFinding.single['id']],
    );

    final summary = await controller.loadSummary();

    expect(summary.totalInspections, 1);
    expect(summary.totalFindings, 1);
    expect(summary.invalidRecordsExcluded, 2);
  });

  test('calcula periodos diario, semanal y mensual', () async {
    await _saveInspection(storage, line: 'RAMAL 1', date: DateTime(2026, 2, 2));
    await _saveInspection(storage, line: 'RAMAL 2', date: DateTime(2026, 2, 3));
    await _saveInspection(
      storage,
      line: 'TRONCAL 1 / SUB 1',
      date: DateTime(2026, 3, 1),
    );

    final summary = await controller.loadSummary();

    expect(summary.dailyInspections, hasLength(3));
    expect(summary.weeklyInspections, hasLength(2));
    expect(
      summary.monthlyInspections
          .firstWhere((item) => item.periodStart == DateTime(2026, 2))
          .count,
      2,
    );
    expect(
      summary.monthlyInspections
          .firstWhere((item) => item.periodStart == DateTime(2026, 3))
          .count,
      1,
    );
  });
}

CatalogData _catalog() {
  return const CatalogData(
    troncalesJson: {
      'TRONCAL 1': ['SUB 1', 'SUB 2'],
    },
    ramalesJson: ['RAMAL 1', 'RAMAL 2'],
  );
}

LineInspectionStatus _status(DashboardSummary summary, String line) {
  return summary.lineStatuses.firstWhere((item) => item.normalizedKey == line);
}

Future<void> _saveInspection(
  LocalDatabaseStorage storage, {
  required String line,
  String tipoLinea = 'Troncal',
  String responsible = 'Operador',
  DateTime? date,
  List<String> findings = const [],
}) {
  return storage.agregarInspeccionCompleta(
    Inspeccion(
      linea: line,
      tipoLinea: tipoLinea,
      responsable: responsible,
      fecha: date ?? DateTime(2026, 2, 20),
      estadoLinea: 'Operativa',
      puntoReferencia: 'KM 1',
      observaciones: 'Obs',
    ),
    findings.map((finding) {
      return HallazgoInspeccion(
        tipo: finding,
        detalle: '',
        latitud: '1',
        longitud: '2',
        descripcion: 'Hallazgo',
      );
    }).toList(),
  );
}

class FakeCatalogRepository implements CatalogRepository {
  CatalogData? catalog;

  FakeCatalogRepository(this.catalog);

  @override
  Future<CatalogData?> cargarCatalogos() async {
    return catalog;
  }
}
