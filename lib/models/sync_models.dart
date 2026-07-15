enum SyncEntityType { inspection, finding }

enum SyncOperationType { create, update, delete }

enum SyncStatus {
  pendingCreate,
  pendingUpdate,
  pendingDelete,
  synced,
  conflict,
  failed,
}

enum SyncWorkerStatus {
  offline,
  syncing,
  synced,
  partialFailure,
  conflict,
  unavailable,
}

class RemoteChangeSet {
  final List<Map<String, Object?>> inspections;
  final List<Map<String, Object?>> findings;
  final DateTime? cursor;

  const RemoteChangeSet({
    required this.inspections,
    required this.findings,
    required this.cursor,
  });
}

class SyncWorkerResult {
  final SyncWorkerStatus status;
  final int processed;
  final int failed;
  final int conflicts;

  const SyncWorkerResult({
    required this.status,
    required this.processed,
    required this.failed,
    required this.conflicts,
  });
}

class SyncMetadata {
  final String globalId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final String deviceId;
  final int localVersion;
  final int remoteVersion;
  final SyncStatus syncStatus;
  final DateTime? lastSyncAt;
  final DateTime? deletedAt;

  const SyncMetadata({
    required this.globalId,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    required this.deviceId,
    required this.localVersion,
    required this.remoteVersion,
    required this.syncStatus,
    this.lastSyncAt,
    this.deletedAt,
  });
}

class SyncQueueEntry {
  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperationType operation;
  final String payloadJson;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isConflict;

  const SyncQueueEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.attempts,
    required this.nextAttemptAt,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.isConflict = false,
  });
}

class SyncQueueOperation {
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperationType operation;
  final String payloadJson;
  final bool isConflict;

  const SyncQueueOperation({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    this.isConflict = false,
  });
}

String syncEntityTypeToStorage(SyncEntityType value) {
  return switch (value) {
    SyncEntityType.inspection => 'inspection',
    SyncEntityType.finding => 'finding',
  };
}

SyncEntityType syncEntityTypeFromStorage(String value) {
  return switch (value) {
    'inspection' => SyncEntityType.inspection,
    'finding' => SyncEntityType.finding,
    _ => throw ArgumentError('Tipo de entidad sync no soportado: $value'),
  };
}

String syncOperationToStorage(SyncOperationType value) {
  return switch (value) {
    SyncOperationType.create => 'create',
    SyncOperationType.update => 'update',
    SyncOperationType.delete => 'delete',
  };
}

SyncOperationType syncOperationFromStorage(String value) {
  return switch (value) {
    'create' => SyncOperationType.create,
    'update' => SyncOperationType.update,
    'delete' => SyncOperationType.delete,
    _ => throw ArgumentError('Operación sync no soportada: $value'),
  };
}

String syncStatusToStorage(SyncStatus value) {
  return switch (value) {
    SyncStatus.pendingCreate => 'pendingCreate',
    SyncStatus.pendingUpdate => 'pendingUpdate',
    SyncStatus.pendingDelete => 'pendingDelete',
    SyncStatus.synced => 'synced',
    SyncStatus.conflict => 'conflict',
    SyncStatus.failed => 'failed',
  };
}

SyncStatus syncStatusFromStorage(String value) {
  return switch (value) {
    'pendingCreate' => SyncStatus.pendingCreate,
    'pendingUpdate' => SyncStatus.pendingUpdate,
    'pendingDelete' => SyncStatus.pendingDelete,
    'synced' => SyncStatus.synced,
    'conflict' => SyncStatus.conflict,
    'failed' => SyncStatus.failed,
    _ => throw ArgumentError('Estado sync no soportado: $value'),
  };
}
