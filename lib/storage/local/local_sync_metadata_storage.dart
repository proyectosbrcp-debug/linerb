import '../../models/sync_models.dart';
import '../sync_metadata_storage.dart';
import 'linerb_database.dart';

class LocalSyncMetadataStorage implements SyncMetadataStorage {
  final LinerbDatabase database;

  const LocalSyncMetadataStorage({required this.database});

  @override
  Future<SyncMetadata?> loadMetadata(
    SyncEntityType entityType,
    String entityId,
  ) async {
    final db = await database.open();
    final rows = await db.query(
      _tableFor(entityType),
      where: 'id = ?',
      whereArgs: [entityId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.single;
    return SyncMetadata(
      globalId: row['global_id'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      createdBy: row['created_by'] as String,
      updatedBy: row['updated_by'] as String,
      deviceId: row['device_id'] as String,
      localVersion: row['local_version'] as int,
      remoteVersion: row['remote_version'] as int,
      syncStatus: syncStatusFromStorage(row['sync_status'] as String),
      lastSyncAt: row['last_sync_at'] == null
          ? null
          : DateTime.parse(row['last_sync_at'] as String),
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at'] as String),
    );
  }

  @override
  Future<void> updateStatus(
    SyncEntityType entityType,
    String entityId,
    SyncStatus status,
  ) async {
    final db = await database.open();
    await db.update(
      _tableFor(entityType),
      {'sync_status': syncStatusToStorage(status)},
      where: 'id = ?',
      whereArgs: [entityId],
    );
  }

  String _tableFor(SyncEntityType entityType) {
    return switch (entityType) {
      SyncEntityType.inspection => 'inspections',
      SyncEntityType.finding => 'hallazgos',
    };
  }
}
