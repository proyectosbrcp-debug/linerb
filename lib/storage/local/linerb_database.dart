import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;

class LinerbDatabase {
  static const int version = 2;
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
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
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
  created_order INTEGER NOT NULL,
  is_invalid INTEGER NOT NULL DEFAULT 0,
  diagnostic_notes TEXT
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
  is_invalid INTEGER NOT NULL DEFAULT 0,
  diagnostic_notes TEXT,
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
  updated_at TEXT NOT NULL,
  is_invalid INTEGER NOT NULL DEFAULT 0,
  diagnostic_notes TEXT
)
''');

    await db.execute('''
CREATE TABLE migration_metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE integrity_issues (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  issue_type TEXT NOT NULL,
  evidence TEXT NOT NULL,
  detected_at TEXT NOT NULL,
  resolution TEXT NOT NULL DEFAULT 'marked'
)
''');

    await _createIndexes(db);
  }

  Future<void> _upgrade(
    sqflite.Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(
        db,
        'inspections',
        'is_invalid',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'inspections', 'diagnostic_notes', 'TEXT');
      await _addColumnIfMissing(
        db,
        'hallazgos',
        'is_invalid',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'hallazgos', 'diagnostic_notes', 'TEXT');
      await _addColumnIfMissing(
        db,
        'draft',
        'is_invalid',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'draft', 'diagnostic_notes', 'TEXT');

      await db.execute('''
CREATE TABLE IF NOT EXISTS integrity_issues (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  issue_type TEXT NOT NULL,
  evidence TEXT NOT NULL,
  detected_at TEXT NOT NULL,
  resolution TEXT NOT NULL DEFAULT 'marked'
)
''');
      await _createIndexes(db);
    }
  }

  Future<void> _createIndexes(sqflite.Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_fecha_iso ON inspections(fecha_iso)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_invalid ON inspections(is_invalid)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_hallazgos_draft_id ON hallazgos(draft_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_hallazgos_inspection_id ON hallazgos(inspection_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_hallazgos_invalid ON hallazgos(is_invalid)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_migration_metadata_value ON migration_metadata(value)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_migration_metadata_updated_at ON migration_metadata(updated_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_integrity_issues_type ON integrity_issues(issue_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_integrity_issues_entity ON integrity_issues(entity_type, entity_id)',
    );
  }

  Future<void> _addColumnIfMissing(
    sqflite.Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);

    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }
}
