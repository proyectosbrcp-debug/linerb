import '../models/sync_models.dart';

abstract class SyncQueueStorage {
  Future<void> enqueue(SyncQueueOperation operation);

  Future<List<SyncQueueEntry>> pendingOperations();

  Future<List<SyncQueueEntry>> pendingOperationsPage({
    required DateTime now,
    int limit = 100,
  }) async {
    final pending = await pendingOperations();
    final eligible =
        pending
            .where(
              (operation) =>
                  operation.nextAttemptAt == null ||
                  !operation.nextAttemptAt!.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return eligible.take(limit).toList();
  }

  Future<bool> hasDuplicate(SyncQueueOperation operation);

  Future<void> markCompleted(String queueEntryId);

  Future<void> registerFailure(String queueEntryId, String error);

  Future<void> incrementAttempts(String queueEntryId);

  Future<void> rescheduleRetry(String queueEntryId, DateTime nextAttemptAt);
}
