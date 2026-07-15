import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/storage/integrity/local_data_integrity_service.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_database_storage.dart';
import 'package:linerb/storage/storage_exceptions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LinerbDatabase database;
  late LocalDatabaseStorage storage;
  late LocalDataIntegrityService integrityService;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    storage = LocalDatabaseStorage(database: database, inspeccionesMemoria: []);
    integrityService = LocalDataIntegrityService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('detecta inspección duplicada sin borrar datos', () async {
    final db = await database.open();
    await _insertInspection(db, 'dup_a');
    await _insertInspection(db, 'dup_b');

    final report = await integrityService.validateAndMark();
    final count = await storage.inspectionCount();
    final invalid = await db.query(
      'inspections',
      where: 'is_invalid = ?',
      whereArgs: [1],
    );

    expect(
      report.issues.map((i) => i.issueType),
      contains('inspection_duplicate'),
    );
    expect(count, 2);
    expect(invalid, hasLength(2));
  });

  test('detecta hallazgo huérfano y lo conserva marcado', () async {
    final db = await database.open();
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.insert('hallazgos', {
      'id': 'orphan_h',
      'inspection_id': 'missing_inspection',
      'draft_id': null,
      'tipo': 'Fuga',
      'detalle': '',
      'latitud': '1',
      'longitud': '2',
      'descripcion': 'Huérfano',
      'foto1_path': null,
      'foto2_path': null,
      'created_order': 0,
    });
    await db.execute('PRAGMA foreign_keys = ON');

    final report = await integrityService.validateAndMark();
    final rows = await db.query(
      'hallazgos',
      where: 'id = ?',
      whereArgs: ['orphan_h'],
    );

    expect(report.issues.map((i) => i.issueType), contains('hallazgo_orphan'));
    expect(rows, hasLength(1));
    expect(rows.single['is_invalid'], 1);
  });

  test('detecta fecha corrupta en inspección', () async {
    final db = await database.open();
    await _insertInspection(db, 'bad_date', fechaIso: 'fecha-corrupta');

    final report = await integrityService.validateAndMark();

    expect(
      report.issues.map((i) => i.issueType),
      contains('inspection_invalid_date'),
    );
  });

  test('detecta borrador incompleto', () async {
    final db = await database.open();
    await db.insert('draft', {
      'id': 'current',
      'usuario': '',
      'tipo_linea': 'Ramal',
      'seleccion_linea': '',
      'responsable': '',
      'punto_referencia': '',
      'estado_linea': '',
      'updated_at': DateTime.now().toIso8601String(),
    });

    final report = await integrityService.validateAndMark();

    expect(report.issues.map((i) => i.issueType), contains('draft_incomplete'));
  });

  test('si falla un hallazgo, la transacción hace rollback completo', () async {
    final failingStorage = LocalDatabaseStorage(
      database: database,
      inspeccionesMemoria: [],
      failOnHallazgoIndex: 0,
    );

    await expectLater(
      failingStorage.agregarInspeccionCompleta(_inspection(), [
        HallazgoInspeccion(
          tipo: 'Fuga',
          detalle: 'Activa',
          latitud: '1',
          longitud: '2',
          descripcion: 'Debe fallar',
        ),
      ]),
      throwsA(isA<StorageWriteException>()),
    );

    expect(await storage.inspectionCount(), 0);
    expect(await storage.hallazgoCount(), 0);
  });
}

Future<void> _insertInspection(
  Database db,
  String id, {
  String fechaIso = '2026-01-01T00:00:00.000',
}) {
  return db.insert('inspections', {
    'id': id,
    'linea': 'LÍNEA DUP',
    'tipo_linea': 'Troncal',
    'responsable': 'Operador',
    'fecha_iso': fechaIso,
    'estado_linea': 'Operativa',
    'punto_referencia': 'KM 1',
    'observaciones': 'Obs',
    'source': 'test',
    'source_key': id,
    'created_order': id.hashCode,
  });
}

Inspeccion _inspection() {
  return Inspeccion(
    linea: 'LÍNEA TX',
    tipoLinea: 'Troncal',
    responsable: 'Operador',
    fecha: DateTime(2026, 1, 1),
    estadoLinea: 'Operativa',
    puntoReferencia: 'KM 1',
    observaciones: 'Obs',
  );
}
