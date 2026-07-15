import '../models/sync_models.dart';

abstract class SyncQueueStorage {
  Future<void> enqueue(SyncQueueOperation operation);

  Future<List<SyncQueueEntry>> pendingOperations();

  Future<bool> hasDuplicate(SyncQueueOperation operation);

  Future<void> markCompleted(String queueEntryId);

  Future<void> registerFailure(String queueEntryId, String error);

  Future<void> incrementAttempts(String queueEntryId);

  Future<void> rescheduleRetry(String queueEntryId, DateTime nextAttemptAt);
}
