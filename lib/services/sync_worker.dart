import 'dart:convert';

import '../core/constants/sync_batch_config.dart';
import '../core/time/app_clock.dart';
import '../models/sync_models.dart';
import '../repositories/sync_repository.dart';
import 'remote_sync_applier.dart';
import 'sync_retry_policy.dart';
import '../storage/sync_metadata_storage.dart';
import '../storage/sync_queue_storage.dart';

class SyncWorker {
  final SyncQueueStorage queueStorage;
  final SyncMetadataStorage metadataStorage;
  final RemoteSyncDataSource? remoteDataSource;
  final RemoteSyncApplier? remoteSyncApplier;
  final Clock clock;
  final SyncRetryPolicy retryPolicy;

  SyncWorker({
    required this.queueStorage,
    required this.metadataStorage,
    required this.remoteDataSource,
    this.remoteSyncApplier,
    this.clock = const SystemClock(),
    SyncRetryPolicy? retryPolicy,
  }) : retryPolicy = retryPolicy ?? SyncRetryPolicy(clock: clock);

  Future<SyncWorkerResult> syncNow({
    bool canPush = true,
    bool canPull = true,
  }) async {
    final remote = remoteDataSource;
    if (remote == null) {
      return const SyncWorkerResult(
        status: SyncWorkerStatus.unavailable,
        processed: 0,
        failed: 0,
        conflicts: 0,
      );
    }

    var processed = 0;
    var failed = 0;
    var conflicts = 0;
    final failedInspections = <String>{};

    if (canPush) {
      while (true) {
        final eligible = await queueStorage.pendingOperationsPage(
          now: clock.now(),
          limit: SyncBatchConfig.pushBatchSize,
        );
        if (eligible.isEmpty) break;

        var pageHadActionableOperation = false;
        for (var index = 0; index < eligible.length; index++) {
          final operation = eligible[index];
          if (operation.isConflict) {
            conflicts++;
            continue;
          }
          if (operation.entityType == SyncEntityType.finding &&
              failedInspections.contains(_inspectionId(operation))) {
            continue;
          }

          pageHadActionableOperation = true;
          try {
            final batch = _batchForInspectionCreate(operation, eligible, index);
            if (batch.length > 1) {
              await remote.pushBatch(batch);
              for (final item in batch) {
                await _markOperationSynced(item);
                processed++;
              }
              index += batch.length - 1;
            } else {
              await remote.push(operation);
              await _markOperationSynced(operation);
              processed++;
            }
          } catch (error) {
            failed++;
            if (operation.entityType == SyncEntityType.inspection) {
              failedInspections.add(operation.entityId);
            }
            final nextAttempt = operation.attempts + 1;
            await queueStorage.incrementAttempts(operation.id);
            await queueStorage.registerFailure(operation.id, error.toString());
            await queueStorage.rescheduleRetry(
              operation.id,
              retryPolicy.nextRetryAt(nextAttempt),
            );
          }
        }

        if (!pageHadActionableOperation ||
            eligible.length < SyncBatchConfig.pushBatchSize) {
          break;
        }
      }
    } else {
      final pending = await queueStorage.pendingOperations();
      conflicts = pending.where((operation) => operation.isConflict).length;
      failed = pending.where((operation) => operation.lastError != null).length;
    }

    var downloaded = 0;
    var applied = 0;
    if (canPull && remoteSyncApplier != null) {
      try {
        for (var page = 0; page < 20; page++) {
          final cursors = await remoteSyncApplier!.loadCursors();
          final changes = await remote.fetchChanges(cursors: cursors);
          final pageDownloaded =
              changes.inspections.length + changes.findings.length;
          if (pageDownloaded == 0) break;

          downloaded += pageDownloaded;
          await remoteSyncApplier!.apply(changes);
          applied += pageDownloaded;

          final reachedPageLimit =
              changes.inspections.length >=
                  SyncBatchConfig.pullInspectionsLimit ||
              changes.findings.length >= SyncBatchConfig.pullFindingsLimit;
          if (!reachedPageLimit) break;
        }
      } catch (error) {
        failed++;
        return SyncWorkerResult(
          status: processed > 0
              ? SyncWorkerStatus.partialFailure
              : SyncWorkerStatus.unavailable,
          processed: processed,
          downloaded: downloaded,
          applied: applied,
          failed: failed,
          conflicts: conflicts,
          error: error,
        );
      }
    }

    final remaining = await queueStorage.pendingOperations();
    conflicts = remaining.where((operation) => operation.isConflict).length;
    failed = remaining.where((operation) => operation.lastError != null).length;

    if (remaining.isEmpty && failed == 0 && conflicts == 0) {
      return SyncWorkerResult(
        status: SyncWorkerStatus.synced,
        processed: processed,
        downloaded: downloaded,
        applied: applied,
        failed: 0,
        conflicts: 0,
      );
    }

    return SyncWorkerResult(
      status: conflicts > 0
          ? SyncWorkerStatus.conflict
          : failed > 0
          ? SyncWorkerStatus.partialFailure
          : SyncWorkerStatus.synced,
      processed: processed,
      downloaded: downloaded,
      applied: applied,
      failed: failed,
      conflicts: conflicts,
    );
  }

  List<SyncQueueEntry> _batchForInspectionCreate(
    SyncQueueEntry operation,
    List<SyncQueueEntry> pending,
    int startIndex,
  ) {
    if (operation.entityType != SyncEntityType.inspection ||
        operation.operation != SyncOperationType.create) {
      return [operation];
    }

    final batch = [operation];
    for (var index = startIndex + 1; index < pending.length; index++) {
      final candidate = pending[index];
      if (candidate.entityType != SyncEntityType.finding ||
          candidate.operation != SyncOperationType.create ||
          candidate.isConflict) {
        break;
      }
      if (_inspectionId(candidate) != operation.entityId) break;
      batch.add(candidate);
    }
    return batch;
  }

  Future<void> _markOperationSynced(SyncQueueEntry operation) async {
    final payload = jsonDecode(operation.payloadJson) as Map;
    final remoteVersion = payload['remote_version'] is int
        ? payload['remote_version'] as int
        : 0;
    await metadataStorage.markSynced(
      operation.entityType,
      operation.entityId,
      remoteVersion: remoteVersion + 1,
      lastSyncAt: clock.now(),
    );
    await queueStorage.markCompleted(operation.id);
  }

  String _inspectionId(SyncQueueEntry operation) {
    if (operation.entityType == SyncEntityType.inspection) {
      return operation.entityId;
    }
    final payload = jsonDecode(operation.payloadJson) as Map;
    return payload['inspection_id'] as String? ??
        payload['inspection_global_id'] as String? ??
        '';
  }
}
