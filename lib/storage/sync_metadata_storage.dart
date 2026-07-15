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

  Future<void> markSynced(
    SyncEntityType entityType,
    String entityId, {
    required int remoteVersion,
    required DateTime lastSyncAt,
  });

  Future<void> markConflict(
    SyncEntityType entityType,
    String entityId, {
    required String remotePayload,
  });
}
