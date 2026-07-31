import '../models/sync_models.dart';
import '../storage/sync_queue_storage.dart';

abstract class RemoteSyncDataSource {
  Future<void> push(SyncQueueEntry operation);

  Future<void> pushBatch(List<SyncQueueEntry> operations);

  Future<void> createInspection(Map<String, Object?> payload);

  Future<void> updateInspection(Map<String, Object?> payload);

  Future<void> deleteInspection(Map<String, Object?> payload);

  Future<void> createFinding(Map<String, Object?> payload);

  Future<void> updateFinding(Map<String, Object?> payload);

  Future<void> deleteFinding(Map<String, Object?> payload);

  Future<RemoteChangeSet> fetchChanges({
    DateTime? since,
    RemoteSyncCursors? cursors,
  });

  Future<List<Map<String, Object?>>> fetchFindingsForInspections(
    List<String> inspectionGlobalIds,
  );
}

abstract class SyncRepository {
  Future<void> enqueue(SyncQueueOperation operation);

  Future<List<SyncQueueEntry>> pendingOperations();
}

class LocalSyncRepository implements SyncRepository {
  final SyncQueueStorage queueStorage;

  const LocalSyncRepository({required this.queueStorage});

  @override
  Future<void> enqueue(SyncQueueOperation operation) {
    return queueStorage.enqueue(operation);
  }

  @override
  Future<List<SyncQueueEntry>> pendingOperations() {
    return queueStorage.pendingOperations();
  }
}
