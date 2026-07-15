import '../models/sync_models.dart';

abstract class SyncMetadataStorage {
  Future<SyncMetadata?> loadMetadata(
    SyncEntityType entityType,
    String entityId,
  );

  Future<void> updateStatus(
    SyncEntityType entityType,
    String entityId,
    SyncStatus status,
  );
}
