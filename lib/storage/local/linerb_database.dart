import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;

class LinerbDatabase {
  static const int version = 1;
  static const String defaultName = 'linerb_v2.db';

  final sqflite.DatabaseFactory? factory;
  final String? databasePath;
  sqflite.Database? _database;

  LinerbDatabase({this.factory, this.databasePath});

  Future<sqflite.Database> open() async {
    final current = _database;
    if (current != null) return current;

    final databaseFactory = factory ?? sqflite.databaseFactory;
    final resolvedPath =
        databasePath ??
        path.join(await sqflite.getDatabasesPath(), defaultName);

    final opened = await databaseFactory.openDatabase(
      resolvedPath,
      options: sqflite.OpenDatabaseOptions(
        version: version,
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );

    _database = opened;
    return opened;
  }

  Future<void> close() async {
    final current = _database;
    _database = null;
    await current?.close();
  }

  Future<void> _create(sqflite.Database db, int version) async {
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

    await db.execute(
      'CREATE INDEX idx_hallazgos_draft_id ON hallazgos(draft_id)',
    );
    await db.execute(
      'CREATE INDEX idx_hallazgos_inspection_id ON hallazgos(inspection_id)',
    );
  }

  Future<void> _upgrade(
    sqflite.Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Versión inicial. Las futuras migraciones se agregan aquí.
  }
}
