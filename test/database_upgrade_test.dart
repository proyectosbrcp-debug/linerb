import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('PRAGMA foreign_keys queda activo al abrir y reabrir SQLite', () async {
    final database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );

    final firstOpen = await database.open();
    expect(await _foreignKeysEnabled(firstOpen), isTrue);

    await database.close();

    final secondOpen = await database.open();
    expect(await _foreignKeysEnabled(secondOpen), isTrue);

    await database.close();
  });

  test('migra base v1 vacía a v2 sin eliminar tablas', () async {
    final path = await _createV1Database();
    final database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );

    final db = await database.open();

    expect(await db.getVersion(), 3);
    expect(await _hasColumn(db, 'inspections', 'is_invalid'), isTrue);
    expect(await _hasColumn(db, 'hallazgos', 'is_invalid'), isTrue);
    expect(await _hasColumn(db, 'draft', 'is_invalid'), isTrue);
    expect(await _hasColumn(db, 'inspections', 'sync_status'), isTrue);
    expect(await _hasColumn(db, 'hallazgos', 'sync_status'), isTrue);
    expect(await _tableExists(db, 'integrity_issues'), isTrue);
    expect(await _tableExists(db, 'sync_queue'), isTrue);

    await database.close();
  });

  test(
    'migra base v1 con datos válidos, source_key nulo y hallazgos',
    () async {
      final path = await _createV1Database(seedValidData: true);
      final database = LinerbDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );

      final db = await database.open();
      final inspections = await db.query('inspections');
      final hallazgos = await db.query('hallazgos');

      expect(await db.getVersion(), 3);
      expect(inspections, hasLength(2));
      expect(
        inspections.where((row) => row['source_key'] == null),
        hasLength(1),
      );
      expect(hallazgos, hasLength(1));
      expect(await _indexExists(db, 'idx_hallazgos_inspection_id'), isTrue);

      await database.close();
    },
  );

  test(
    'upgrade no crea UNIQUE nuevo de source_key que bloquee duplicados heredados',
    () async {
      final path = await _createLooseV1DatabaseWithDuplicateSourceKeys();
      final database = LinerbDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );

      final db = await database.open();
      final rows = await db.query(
        'inspections',
        where: 'source_key = ?',
        whereArgs: ['duplicada'],
      );

      expect(await db.getVersion(), 3);
      expect(rows, hasLength(2));
      expect(await _hasColumn(db, 'inspections', 'is_invalid'), isTrue);

      await database.close();
    },
  );

  test('migra base v1 con registros incompletos sin borrarlos', () async {
    final path = await _createLooseV1DatabaseWithIncompleteRows();
    final database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );

    final db = await database.open();
    final inspections = await db.query('inspections');
    final hallazgos = await db.query('hallazgos');

    expect(await db.getVersion(), 3);
    expect(inspections, hasLength(1));
    expect(hallazgos, hasLength(1));
    expect(await _hasColumn(db, 'inspections', 'diagnostic_notes'), isTrue);

    await database.close();
  });
}

Future<String> _createV1Database({bool seedValidData = false}) async {
  final databasePath = await _temporaryDatabasePath();
  final db = await databaseFactoryFfi.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await _createStrictV1Schema(db);
        if (seedValidData) {
          await _seedValidV1Data(db);
        }
      },
    ),
  );
  await db.close();
  return databasePath;
}

Future<String> _createLooseV1DatabaseWithDuplicateSourceKeys() async {
  final databasePath = await _temporaryDatabasePath();
  final db = await databaseFactoryFfi.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await _createLooseV1Schema(db);
        await _insertLooseInspection(db, 'dup_1', 'duplicada');
        await _insertLooseInspection(db, 'dup_2', 'duplicada');
      },
    ),
  );
  await db.close();
  return databasePath;
}

Future<String> _createLooseV1DatabaseWithIncompleteRows() async {
  final databasePath = await _temporaryDatabasePath();
  final db = await databaseFactoryFfi.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await _createLooseV1Schema(db);
        await db.insert('inspections', {
          'id': 'incomplete_inspection',
          'linea': null,
          'tipo_linea': 'Troncal',
          'responsable': null,
          'fecha_iso': 'fecha-corrupta',
          'estado_linea': 'Operativa',
          'punto_referencia': null,
          'observaciones': null,
          'source': 'legacy',
          'source_key': null,
          'created_order': 1,
        });
        await db.insert('hallazgos', {
          'id': 'incomplete_hallazgo',
          'inspection_id': 'incomplete_inspection',
          'draft_id': null,
          'tipo': null,
          'detalle': null,
          'latitud': null,
          'longitud': null,
          'descripcion': null,
          'foto1_path': null,
          'foto2_path': null,
          'created_order': 1,
        });
      },
    ),
  );
  await db.close();
  return databasePath;
}

Future<String> _temporaryDatabasePath() async {
  final directory = await Directory.systemTemp.createTemp(
    'linerb_upgrade_test_',
  );
  return path.join(directory.path, 'linerb_upgrade.db');
}

Future<void> _createStrictV1Schema(Database db) async {
  await db.execute('''
CREATE TABLE inspections (
  id TEXT PRIMARY KEY,
  linea TEXT NOT NULL,
  tipo_linea TEXT NOT NULL,
  responsable TEXT NOT NULL,
  fecha_iso TEXT NOT NULL,
  estado_linea TEXT NOT NULL,
  punto_referencia TEXT NOT NULL,
  observaciones TEXT NOT NULL,
  source TEXT NOT NULL,
  source_key TEXT UNIQUE,
  created_order INTEGER NOT NULL
)
''');
  await db.execute('''
CREATE TABLE hallazgos (
  id TEXT PRIMARY KEY,
  inspection_id TEXT,
  draft_id TEXT,
  tipo TEXT NOT NULL,
  detalle TEXT NOT NULL,
  latitud TEXT NOT NULL,
  longitud TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  foto1_path TEXT,
  foto2_path TEXT,
  created_order INTEGER NOT NULL,
  FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE
)
''');
  await db.execute('''
CREATE TABLE draft (
  id TEXT PRIMARY KEY,
  usuario TEXT NOT NULL,
  tipo_linea TEXT NOT NULL,
  seleccion_linea TEXT NOT NULL,
  responsable TEXT NOT NULL,
  punto_referencia TEXT NOT NULL,
  estado_linea TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
  await db.execute('''
CREATE TABLE migration_metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
}

Future<void> _createLooseV1Schema(Database db) async {
  await db.execute('''
CREATE TABLE inspections (
  id TEXT,
  linea TEXT,
  tipo_linea TEXT,
  responsable TEXT,
  fecha_iso TEXT,
  estado_linea TEXT,
  punto_referencia TEXT,
  observaciones TEXT,
  source TEXT,
  source_key TEXT,
  created_order INTEGER
)
''');
  await db.execute('''
CREATE TABLE hallazgos (
  id TEXT,
  inspection_id TEXT,
  draft_id TEXT,
  tipo TEXT,
  detalle TEXT,
  latitud TEXT,
  longitud TEXT,
  descripcion TEXT,
  foto1_path TEXT,
  foto2_path TEXT,
  created_order INTEGER
)
''');
  await db.execute('''
CREATE TABLE draft (
  id TEXT,
  usuario TEXT,
  tipo_linea TEXT,
  seleccion_linea TEXT,
  responsable TEXT,
  punto_referencia TEXT,
  estado_linea TEXT,
  updated_at TEXT
)
''');
  await db.execute('''
CREATE TABLE migration_metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
}

Future<void> _seedValidV1Data(Database db) async {
  await _insertStrictInspection(db, 'valid_1', 'source_1');
  await _insertStrictInspection(db, 'valid_null_source', null);
  await db.insert('hallazgos', {
    'id': 'hallazgo_1',
    'inspection_id': 'valid_1',
    'draft_id': null,
    'tipo': 'Fuga',
    'detalle': 'Activa',
    'latitud': '1',
    'longitud': '2',
    'descripcion': 'Hallazgo válido',
    'foto1_path': null,
    'foto2_path': null,
    'created_order': 1,
  });
}

Future<void> _insertStrictInspection(
  Database db,
  String id,
  String? sourceKey,
) {
  return db.insert('inspections', {
    'id': id,
    'linea': 'LÍNEA $id',
    'tipo_linea': 'Troncal',
    'responsable': 'Operador',
    'fecha_iso': '2026-01-01T00:00:00.000',
    'estado_linea': 'Operativa',
    'punto_referencia': 'KM 1',
    'observaciones': 'Obs',
    'source': 'test',
    'source_key': sourceKey,
    'created_order': id.hashCode,
  });
}

Future<void> _insertLooseInspection(Database db, String id, String sourceKey) {
  return db.insert('inspections', {
    'id': id,
    'linea': 'LÍNEA $id',
    'tipo_linea': 'Troncal',
    'responsable': 'Operador',
    'fecha_iso': '2026-01-01T00:00:00.000',
    'estado_linea': 'Operativa',
    'punto_referencia': 'KM 1',
    'observaciones': 'Obs',
    'source': 'test',
    'source_key': sourceKey,
    'created_order': id.hashCode,
  });
}

Future<bool> _foreignKeysEnabled(Database db) async {
  final result = await db.rawQuery('PRAGMA foreign_keys');
  return result.single.values.single == 1;
}

Future<bool> _hasColumn(Database db, String table, String column) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.any((row) => row['name'] == column);
}

Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.query(
    'sqlite_master',
    where: 'type = ? AND name = ?',
    whereArgs: ['table', table],
  );
  return rows.isNotEmpty;
}

Future<bool> _indexExists(Database db, String index) async {
  final rows = await db.query(
    'sqlite_master',
    where: 'type = ? AND name = ?',
    whereArgs: ['index', index],
  );
  return rows.isNotEmpty;
}
