import 'package:sqflite/sqflite.dart';

import '../../core/time/app_clock.dart';
import '../../core/utils/stable_id.dart';
import '../../models/sync_models.dart';
import '../sync_queue_storage.dart';
import 'linerb_database.dart';

class LocalSyncQueueStorage implements SyncQueueStorage {
  final LinerbDatabase database;
  final Clock clock;
  final bool failWrites;

  const LocalSyncQueueStorage({
    required this.database,
    this.clock = const SystemClock(),
    this.failWrites = false,
  });

  @override
  Future<void> enqueue(SyncQueueOperation operation) async {
    if (failWrites) {
      throw StateError('Fallo simulado de cola de sincronización');
    }
    final db = await database.open();
    await db.transaction((txn) async {
      await enqueueInTransaction(txn, operation);
    });
  }

  Future<void> enqueueInTransaction(
    DatabaseExecutor txn,
    SyncQueueOperation operation,
  ) async {
    if (failWrites) {
      throw StateError('Fallo simulado de cola de sincronización');
    }

    final existing = await _loadExisting(txn, operation);
    if (existing == null) {
      await _insert(txn, operation);
      return;
    }

    if (existing.isConflict || operation.isConflict) {
      await _insert(txn, operation);
      return;
    }

    final compacted = _compact(existing.operation, operation.operation);
    if (compacted == null) {
      await txn.delete('sync_queue', where: 'id = ?', whereArgs: [existing.id]);
      return;
    }

    await txn.update(
      'sync_queue',
      {
        'operation': syncOperationToStorage(compacted),
        'payload_json': operation.payloadJson,
        'updated_at': clock.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [existing.id],
    );
  }

  @override
  Future<List<SyncQueueEntry>> pendingOperations() async {
    final db = await database.open();
    final rows = await db.query('sync_queue', orderBy: 'created_at ASC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<bool> hasDuplicate(SyncQueueOperation operation) async {
    final db = await database.open();
    final existing = await _loadExisting(db, operation);
    return existing != null;
  }

  @override
  Future<void> markCompleted(String queueEntryId) async {
    final db = await database.open();
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [queueEntryId]);
  }

  @override
  Future<void> registerFailure(String queueEntryId, String error) async {
    final db = await database.open();
    await db.update(
      'sync_queue',
      {'last_error': error, 'updated_at': clock.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [queueEntryId],
    );
  }

  @override
  Future<void> incrementAttempts(String queueEntryId) async {
    final db = await database.open();
    await db.rawUpdate(
      '''
UPDATE sync_queue
SET attempts = attempts + 1,
    updated_at = ?
WHERE id = ?
''',
      [clock.now().toIso8601String(), queueEntryId],
    );
  }

  @override
  Future<void> rescheduleRetry(
    String queueEntryId,
    DateTime nextAttemptAt,
  ) async {
    final db = await database.open();
    await db.update(
      'sync_queue',
      {
        'next_attempt_at': nextAttemptAt.toIso8601String(),
        'updated_at': clock.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [queueEntryId],
    );
  }

  Future<SyncQueueEntry?> _loadExisting(
    DatabaseExecutor executor,
    SyncQueueOperation operation,
  ) async {
    final rows = await executor.query(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [
        syncEntityTypeToStorage(operation.entityType),
        operation.entityId,
      ],
      orderBy: 'created_at ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  Future<void> _insert(
    DatabaseExecutor txn,
    SyncQueueOperation operation,
  ) async {
    final now = clock.now();
    await txn.insert('sync_queue', {
      'id': StableId.fromParts('sync_queue', [
        syncEntityTypeToStorage(operation.entityType),
        operation.entityId,
        syncOperationToStorage(operation.operation),
        operation.payloadJson,
        now.toIso8601String(),
      ]),
      'entity_type': syncEntityTypeToStorage(operation.entityType),
      'entity_id': operation.entityId,
      'operation': syncOperationToStorage(operation.operation),
      'payload_json': operation.payloadJson,
      'attempts': 0,
      'next_attempt_at': null,
      'last_error': null,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'is_conflict': operation.isConflict ? 1 : 0,
    });
  }

  SyncOperationType? _compact(
    SyncOperationType existing,
    SyncOperationType incoming,
  ) {
    if (existing == SyncOperationType.create &&
        incoming == SyncOperationType.update) {
      return SyncOperationType.create;
    }
    if (existing == SyncOperationType.update &&
        incoming == SyncOperationType.update) {
      return SyncOperationType.update;
    }
    if (existing == SyncOperationType.create &&
        incoming == SyncOperationType.delete) {
      return null;
    }
    if (existing == SyncOperationType.update &&
        incoming == SyncOperationType.delete) {
      return SyncOperationType.delete;
    }
    return incoming;
  }

  SyncQueueEntry _fromRow(Map<String, Object?> row) {
    return SyncQueueEntry(
      id: row['id'] as String,
      entityType: syncEntityTypeFromStorage(row['entity_type'] as String),
      entityId: row['entity_id'] as String,
      operation: syncOperationFromStorage(row['operation'] as String),
      payloadJson: row['payload_json'] as String,
      attempts: row['attempts'] as int,
      nextAttemptAt: row['next_attempt_at'] == null
          ? null
          : DateTime.parse(row['next_attempt_at'] as String),
      lastError: row['last_error'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      isConflict: row['is_conflict'] == 1,
    );
  }
}
