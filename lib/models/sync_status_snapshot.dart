import 'user_profile.dart';

enum SyncPhase {
  idle,
  waitingForConnectivity,
  waitingForAuthentication,
  syncing,
  synchronized,
  pendingChanges,
  partialSuccess,
  transientFailure,
  permissionDenied,
  conflict,
  unavailable,
  stopped,
}

enum SyncTrigger {
  appStart,
  inspectionFinalized,
  connectivityRecovered,
  periodic,
  manual,
  authSessionRestored,
  retry,
}

enum SyncErrorCategory {
  network,
  unavailable,
  timeout,
  authentication,
  permission,
  invalidData,
  conflict,
  localStorage,
  remoteStorage,
  rateLimited,
  unknown,
}

class SyncDiagnostics {
  final int totalCycles;
  final int successfulCycles;
  final int partialCycles;
  final int failedCycles;
  final Duration averageDuration;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final int currentPending;
  final int maxPendingObserved;
  final int retries;
  final int conflicts;
  final bool degraded;

  const SyncDiagnostics({
    this.totalCycles = 0,
    this.successfulCycles = 0,
    this.partialCycles = 0,
    this.failedCycles = 0,
    this.averageDuration = Duration.zero,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.currentPending = 0,
    this.maxPendingObserved = 0,
    this.retries = 0,
    this.conflicts = 0,
    this.degraded = false,
  });

  SyncDiagnostics recordCycle({
    required SyncPhase phase,
    required Duration duration,
    required int pending,
    required int conflicts,
    bool retried = false,
    required DateTime now,
  }) {
    final nextTotal = totalCycles + 1;
    final nextAverage = Duration(
      microseconds:
          ((averageDuration.inMicroseconds * totalCycles) +
              duration.inMicroseconds) ~/
          nextTotal,
    );
    final success = phase == SyncPhase.synchronized;
    final partial = phase == SyncPhase.partialSuccess;
    final failed =
        phase == SyncPhase.transientFailure ||
        phase == SyncPhase.permissionDenied ||
        phase == SyncPhase.unavailable ||
        phase == SyncPhase.conflict;

    return SyncDiagnostics(
      totalCycles: nextTotal,
      successfulCycles: successfulCycles + (success ? 1 : 0),
      partialCycles: partialCycles + (partial ? 1 : 0),
      failedCycles: failedCycles + (failed ? 1 : 0),
      averageDuration: nextAverage,
      lastSuccessAt: success ? now : lastSuccessAt,
      lastFailureAt: failed ? now : lastFailureAt,
      currentPending: pending,
      maxPendingObserved: pending > maxPendingObserved
          ? pending
          : maxPendingObserved,
      retries: retries + (retried ? 1 : 0),
      conflicts: conflicts,
      degraded: degraded || phase == SyncPhase.unavailable,
    );
  }
}

class SyncStatusSnapshot {
  final SyncPhase phase;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? lastSuccessfulSyncAt;
  final DateTime? lastAttemptAt;
  final int uploadedCount;
  final int downloadedCount;
  final int appliedCount;
  final int failedCount;
  final int pendingCount;
  final int conflictCount;
  final int requiresAttentionCount;
  final DateTime? retryScheduledAt;
  final bool connectivityAvailable;
  final bool authenticated;
  final bool profileActive;
  final bool canPush;
  final bool canPull;
  final SyncErrorCategory? lastErrorCategory;
  final DateTime? lastErrorAt;
  final Duration? duration;
  final SyncTrigger? trigger;
  final UserRole? role;
  final SyncDiagnostics diagnostics;

  const SyncStatusSnapshot({
    required this.phase,
    this.startedAt,
    this.finishedAt,
    this.lastSuccessfulSyncAt,
    this.lastAttemptAt,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.appliedCount = 0,
    this.failedCount = 0,
    this.pendingCount = 0,
    this.conflictCount = 0,
    this.requiresAttentionCount = 0,
    this.retryScheduledAt,
    this.connectivityAvailable = true,
    this.authenticated = false,
    this.profileActive = false,
    this.canPush = false,
    this.canPull = false,
    this.lastErrorCategory,
    this.lastErrorAt,
    this.duration,
    this.trigger,
    this.role,
    this.diagnostics = const SyncDiagnostics(),
  });

  const SyncStatusSnapshot.initial()
    : this(phase: SyncPhase.idle, connectivityAvailable: true);

  bool get isTrulySynchronized {
    return phase == SyncPhase.synchronized &&
        pendingCount == 0 &&
        failedCount == 0 &&
        conflictCount == 0 &&
        authenticated &&
        profileActive &&
        lastSuccessfulSyncAt != null;
  }

  bool get hasPendingWork {
    return pendingCount > 0 || failedCount > 0 || conflictCount > 0;
  }

  SyncStatusSnapshot copyWith({
    SyncPhase? phase,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? lastSuccessfulSyncAt,
    DateTime? lastAttemptAt,
    int? uploadedCount,
    int? downloadedCount,
    int? appliedCount,
    int? failedCount,
    int? pendingCount,
    int? conflictCount,
    int? requiresAttentionCount,
    DateTime? retryScheduledAt,
    bool? connectivityAvailable,
    bool? authenticated,
    bool? profileActive,
    bool? canPush,
    bool? canPull,
    SyncErrorCategory? lastErrorCategory,
    DateTime? lastErrorAt,
    Duration? duration,
    SyncTrigger? trigger,
    UserRole? role,
    SyncDiagnostics? diagnostics,
    bool clearRetry = false,
    bool clearError = false,
  }) {
    return SyncStatusSnapshot(
      phase: phase ?? this.phase,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      lastSuccessfulSyncAt: lastSuccessfulSyncAt ?? this.lastSuccessfulSyncAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      uploadedCount: uploadedCount ?? this.uploadedCount,
      downloadedCount: downloadedCount ?? this.downloadedCount,
      appliedCount: appliedCount ?? this.appliedCount,
      failedCount: failedCount ?? this.failedCount,
      pendingCount: pendingCount ?? this.pendingCount,
      conflictCount: conflictCount ?? this.conflictCount,
      requiresAttentionCount:
          requiresAttentionCount ?? this.requiresAttentionCount,
      retryScheduledAt: clearRetry
          ? null
          : retryScheduledAt ?? this.retryScheduledAt,
      connectivityAvailable:
          connectivityAvailable ?? this.connectivityAvailable,
      authenticated: authenticated ?? this.authenticated,
      profileActive: profileActive ?? this.profileActive,
      canPush: canPush ?? this.canPush,
      canPull: canPull ?? this.canPull,
      lastErrorCategory: clearError
          ? null
          : lastErrorCategory ?? this.lastErrorCategory,
      lastErrorAt: clearError ? null : lastErrorAt ?? this.lastErrorAt,
      duration: duration ?? this.duration,
      trigger: trigger ?? this.trigger,
      role: role ?? this.role,
      diagnostics: diagnostics ?? this.diagnostics,
    );
  }
}
