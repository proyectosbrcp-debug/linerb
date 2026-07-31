import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;

class LinerbDatabase {
  static const int version = 4;
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
    await _addSyncColumnsOnCreate(db, 'inspections');

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
    await _addSyncColumnsOnCreate(db, 'hallazgos');

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

    await _createSyncQueue(db);
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
    }

    if (oldVersion < 3) {
      await _addSyncColumnsForUpgrade(db, 'inspections');
      await _addSyncColumnsForUpgrade(db, 'hallazgos');
      await _createSyncQueue(db);
      await _backfillSyncMetadata(db, 'inspections');
      await _backfillSyncMetadata(db, 'hallazgos');
      await _createIndexes(db);
    }

    if (oldVersion < 4) {
      await _createIndexes(db);
    }
  }

  Future<void> _addSyncColumnsOnCreate(
    sqflite.Database db,
    String table,
  ) async {
    await db.execute(
      'ALTER TABLE $table ADD COLUMN global_id TEXT NOT NULL DEFAULT ""',
    );
    await db.execute(
      'ALTER TABLE $table ADD COLUMN created_at TEXT NOT NULL DEFAULT ""',
    );
    await db.execute(
      'ALTER TABLE $table ADD COLUMN updated_at TEXT NOT NULL DEFAULT ""',
    );
    await db.execute(
      'ALTER TABLE $table ADD COLUMN created_by TEXT NOT NULL DEFAULT ""',
    );
    await db.execute(
      'ALTER TABLE $table ADD COLUMN updated_by TEXT NOT NULL DEFAULT ""',
    );
    await db.execute(
      'ALTER TABLE $table ADD COLUMN device_id TEXT NOT NULL DEFAULT ""',
    );
    await db.execute(
      'ALTER TABLE $table ADD COLUMN local_version INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      'ALTER TABLE $table ADD COLUMN remote_version INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE $table ADD COLUMN sync_status TEXT NOT NULL DEFAULT "synced"',
    );
    await db.execute('ALTER TABLE $table ADD COLUMN last_sync_at TEXT');
    await db.execute('ALTER TABLE $table ADD COLUMN deleted_at TEXT');
  }

  Future<void> _addSyncColumnsForUpgrade(
    sqflite.Database db,
    String table,
  ) async {
    await _addColumnIfMissing(
      db,
      table,
      'global_id',
      'TEXT NOT NULL DEFAULT ""',
    );
    await _addColumnIfMissing(
      db,
      table,
      'created_at',
      'TEXT NOT NULL DEFAULT ""',
    );
    await _addColumnIfMissing(
      db,
      table,
      'updated_at',
      'TEXT NOT NULL DEFAULT ""',
    );
    await _addColumnIfMissing(
      db,
      table,
      'created_by',
      'TEXT NOT NULL DEFAULT ""',
    );
    await _addColumnIfMissing(
      db,
      table,
      'updated_by',
      'TEXT NOT NULL DEFAULT ""',
    );
    await _addColumnIfMissing(
      db,
      table,
      'device_id',
      'TEXT NOT NULL DEFAULT ""',
    );
    await _addColumnIfMissing(
      db,
      table,
      'local_version',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(
      db,
      table,
      'remote_version',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      table,
      'sync_status',
      'TEXT NOT NULL DEFAULT "synced"',
    );
    await _addColumnIfMissing(db, table, 'last_sync_at', 'TEXT');
    await _addColumnIfMissing(db, table, 'deleted_at', 'TEXT');
  }

  Future<void> _createSyncQueue(sqflite.Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS sync_queue (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  next_attempt_at TEXT,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_conflict INTEGER NOT NULL DEFAULT 0
)
''');
  }

  Future<void> _backfillSyncMetadata(sqflite.Database db, String table) async {
    const timestamp = '1970-01-01T00:00:00.000';
    await db.rawUpdate(
      '''
UPDATE $table
SET global_id = CASE WHEN global_id = '' THEN id ELSE global_id END,
    created_at = CASE WHEN created_at = '' THEN ? ELSE created_at END,
    updated_at = CASE WHEN updated_at = '' THEN ? ELSE updated_at END,
    created_by = CASE WHEN created_by = '' THEN 'legacy' ELSE created_by END,
    updated_by = CASE WHEN updated_by = '' THEN 'legacy' ELSE updated_by END,
    device_id = CASE WHEN device_id = '' THEN 'legacy_device' ELSE device_id END,
    sync_status = CASE WHEN sync_status = '' THEN 'synced' ELSE sync_status END
WHERE global_id = ''
   OR created_at = ''
   OR updated_at = ''
   OR created_by = ''
   OR updated_by = ''
   OR device_id = ''
   OR sync_status = ''
''',
      [timestamp, timestamp],
    );
  }

  Future<void> _createIndexes(sqflite.Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_fecha_iso ON inspections(fecha_iso)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_history_cursor ON inspections(fecha_iso DESC, global_id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_invalid ON inspections(is_invalid)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_valid_fecha ON inspections(is_invalid, fecha_iso DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_sync_status ON inspections(sync_status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_global_id ON inspections(global_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_updated_at_global_id ON inspections(updated_at, global_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_responsable ON inspections(responsable)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_tipo_linea ON inspections(tipo_linea)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inspections_deleted_at ON inspections(deleted_at)',
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
      'CREATE INDEX IF NOT EXISTS idx_hallazgos_sync_status ON hallazgos(sync_status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_hallazgos_global_id ON hallazgos(global_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_hallazgos_updated_at_global_id ON hallazgos(updated_at, global_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_hallazgos_categoria ON hallazgos(tipo)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_hallazgos_valid_inspection ON hallazgos(is_invalid, inspection_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_pending ON sync_queue(entity_type, entity_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_next_attempt ON sync_queue(next_attempt_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_due ON sync_queue(next_attempt_at, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_created_at ON sync_queue(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_attempts ON sync_queue(attempts)',
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
