import 'dart:convert';

import '../core/time/app_clock.dart';
import '../models/sync_models.dart';
import '../repositories/sync_repository.dart';
import '../storage/sync_metadata_storage.dart';
import '../storage/sync_queue_storage.dart';

class SyncWorker {
  final SyncQueueStorage queueStorage;
  final SyncMetadataStorage metadataStorage;
  final RemoteSyncDataSource? remoteDataSource;
  final Clock clock;
  final Duration retryDelay;

  const SyncWorker({
    required this.queueStorage,
    required this.metadataStorage,
    required this.remoteDataSource,
    this.clock = const SystemClock(),
    this.retryDelay = const Duration(minutes: 5),
  });

  Future<SyncWorkerResult> syncNow() async {
    final remote = remoteDataSource;
    if (remote == null) {
      return const SyncWorkerResult(
        status: SyncWorkerStatus.unavailable,
        processed: 0,
        failed: 0,
        conflicts: 0,
      );
    }

    final pending = await queueStorage.pendingOperations();
    if (pending.isEmpty) {
      return const SyncWorkerResult(
        status: SyncWorkerStatus.synced,
        processed: 0,
        failed: 0,
        conflicts: 0,
      );
    }

    var processed = 0;
    var failed = 0;
    var conflicts = 0;
    final failedInspections = <String>{};

    for (var index = 0; index < pending.length; index++) {
      final operation = pending[index];
      if (operation.isConflict) {
        conflicts++;
        continue;
      }
      if (operation.entityType == SyncEntityType.finding &&
          failedInspections.contains(_inspectionId(operation))) {
        continue;
      }

      try {
        final batch = _batchForInspectionCreate(operation, pending, index);
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
        await queueStorage.incrementAttempts(operation.id);
        await queueStorage.registerFailure(operation.id, error.toString());
        await queueStorage.rescheduleRetry(
          operation.id,
          clock.now().add(retryDelay),
        );
      }
    }

    return SyncWorkerResult(
      status: conflicts > 0
          ? SyncWorkerStatus.conflict
          : failed > 0
          ? SyncWorkerStatus.partialFailure
          : SyncWorkerStatus.synced,
      processed: processed,
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
