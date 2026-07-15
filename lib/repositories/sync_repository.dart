import '../models/sync_models.dart';
import '../storage/sync_queue_storage.dart';

abstract class RemoteSyncDataSource {
  Future<void> push(SyncQueueEntry operation);
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
