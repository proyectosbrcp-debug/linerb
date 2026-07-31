import 'dart:async';

import '../controllers/auth_controller.dart';
import '../core/logging/app_logger.dart';
import '../core/runtime/app_runtime_initializer.dart';
import '../core/time/app_clock.dart';
import '../models/auth_models.dart';
import '../models/sync_models.dart';
import '../models/sync_status_snapshot.dart';
import '../models/user_profile.dart';
import '../services/permission_service.dart';
import '../storage/sync_queue_storage.dart';
import '../storage/sync_status_storage.dart';
import 'sync_error_classifier.dart';
import 'sync_worker.dart';

typedef SyncWorkerFactory = SyncWorker Function();

class AutomaticSyncCoordinator {
  final SyncWorkerFactory workerFactory;
  final SyncQueueStorage queueStorage;
  final AuthController authController;
  final PermissionService permissionService;
  final SyncStatusStorage? statusStorage;
  final RuntimeInitializationStatus Function() runtimeStatusProvider;
  final Clock clock;
  final Duration periodicInterval;
  final Duration connectivityDebounce;
  final SyncErrorClassifier errorClassifier;

  final StreamController<SyncStatusSnapshot> _controller =
      StreamController<SyncStatusSnapshot>.broadcast();

  SyncStatusSnapshot _snapshot = const SyncStatusSnapshot.initial();
  Timer? _periodicTimer;
  Timer? _retryTimer;
  Timer? _connectivityTimer;
  bool _isRunning = false;
  bool _queuedCycleRequested = false;
  SyncTrigger _queuedTrigger = SyncTrigger.manual;
  bool _disposed = false;
  bool _connectivityAvailable = true;

  AutomaticSyncCoordinator({
    required this.workerFactory,
    required this.queueStorage,
    required this.authController,
    required this.permissionService,
    this.statusStorage,
    required this.runtimeStatusProvider,
    this.clock = const SystemClock(),
    this.periodicInterval = const Duration(minutes: 15),
    this.connectivityDebounce = const Duration(seconds: 2),
    this.errorClassifier = const SyncErrorClassifier(),
  });

  Stream<SyncStatusSnapshot> get stream => _controller.stream;

  SyncStatusSnapshot get snapshot => _snapshot;

  Future<void> restore() async {
    SyncStatusSnapshot? restored;
    try {
      restored = await statusStorage?.restore();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Sync no pudo restaurar estado local',
        error,
        stackTrace,
      );
      _publish(
        _snapshot.copyWith(
          phase: SyncPhase.transientFailure,
          lastErrorCategory: SyncErrorCategory.localStorage,
          lastErrorAt: clock.now(),
        ),
        persist: false,
      );
    }
    if (restored == null) return;
    _publish(
      restored.copyWith(
        phase: restored.phase == SyncPhase.syncing
            ? SyncPhase.transientFailure
            : restored.phase,
      ),
      persist: false,
    );
  }

  Future<void> start({SyncTrigger trigger = SyncTrigger.appStart}) async {
    if (_disposed) return;
    _schedulePeriodic();
    await syncNow(trigger: trigger);
  }

  Future<void> syncNow({SyncTrigger trigger = SyncTrigger.manual}) async {
    return _syncNow(trigger: trigger, queuedCycle: false);
  }

  Future<void> _syncNow({
    required SyncTrigger trigger,
    required bool queuedCycle,
  }) async {
    if (_disposed) return;
    if (_isRunning) {
      if (!queuedCycle) {
        _queuedCycleRequested = true;
        _queuedTrigger = trigger;
      }
      AppLogger.info('Sync ignorado: ciclo ya en curso');
      return;
    }
    _isRunning = true;

    final now = clock.now();
    final profile = authController.currentProfile;
    final authStatus = authController.state.status;
    final permissions = _permissions(profile, authStatus);
    late final List<SyncQueueEntry> queue;
    try {
      queue = await queueStorage.pendingOperations();
    } catch (error, stackTrace) {
      _isRunning = false;
      AppLogger.warning('Sync no pudo leer cola local', error, stackTrace);
      _publish(
        _baseSnapshot(
          phase: SyncPhase.transientFailure,
          trigger: trigger,
          startedAt: now,
          finishedAt: now,
          lastAttemptAt: now,
          permissions: permissions,
          lastErrorCategory: SyncErrorCategory.localStorage,
          lastErrorAt: now,
          duration: Duration.zero,
        ),
      );
      return;
    }
    final pendingCount = queue.length;
    final conflictCount = queue.where((item) => item.isConflict).length;
    final failedCount = queue.where((item) => item.lastError != null).length;
    final requiresAttention = queue.where(_requiresAttention).length;

    if (!_connectivityAvailable) {
      _publish(
        _baseSnapshot(
          phase: SyncPhase.waitingForConnectivity,
          trigger: trigger,
          pendingCount: pendingCount,
          failedCount: failedCount,
          conflictCount: conflictCount,
          requiresAttentionCount: requiresAttention,
          permissions: permissions,
        ),
      );
      _isRunning = false;
      return;
    }

    if (!permissions.authenticated) {
      _publish(
        _baseSnapshot(
          phase: SyncPhase.waitingForAuthentication,
          trigger: trigger,
          pendingCount: pendingCount,
          failedCount: failedCount,
          conflictCount: conflictCount,
          requiresAttentionCount: requiresAttention,
          permissions: permissions,
        ),
      );
      _isRunning = false;
      return;
    }

    if (!permissions.profileActive) {
      _publish(
        _baseSnapshot(
          phase: SyncPhase.permissionDenied,
          trigger: trigger,
          pendingCount: pendingCount,
          failedCount: failedCount,
          conflictCount: conflictCount,
          requiresAttentionCount: requiresAttention,
          permissions: permissions,
          lastErrorCategory: SyncErrorCategory.permission,
          lastErrorAt: now,
        ),
      );
      _isRunning = false;
      return;
    }

    if (pendingCount > 0 && !permissions.canPush) {
      _publish(
        _baseSnapshot(
          phase: SyncPhase.permissionDenied,
          trigger: trigger,
          pendingCount: pendingCount,
          failedCount: failedCount,
          conflictCount: conflictCount,
          requiresAttentionCount: requiresAttention,
          permissions: permissions,
          lastErrorCategory: SyncErrorCategory.permission,
          lastErrorAt: now,
        ),
      );
      _isRunning = false;
      await _runPullOnly(trigger, permissions);
      return;
    }

    _cancelRetryTimer();
    _publish(
      _baseSnapshot(
        phase: SyncPhase.syncing,
        trigger: trigger,
        startedAt: now,
        lastAttemptAt: now,
        pendingCount: pendingCount,
        failedCount: failedCount,
        conflictCount: conflictCount,
        requiresAttentionCount: requiresAttention,
        permissions: permissions,
      ),
    );

    try {
      final result = await workerFactory().syncNow(
        canPush: permissions.canPush,
        canPull: permissions.canPull,
      );
      await _finishCycle(result, trigger, permissions, startedAt: now);
    } catch (error, stackTrace) {
      final category = errorClassifier.classify(error);
      AppLogger.warning(
        'Sync falló: category=${category.name}',
        error,
        stackTrace,
      );
      await _finishFailure(
        category,
        trigger,
        permissions,
        startedAt: now,
        error: error,
      );
    } finally {
      _isRunning = false;
      if (!queuedCycle && _queuedCycleRequested && !_disposed) {
        final nextTrigger = _queuedTrigger;
        _queuedCycleRequested = false;
        unawaited(_syncNow(trigger: nextTrigger, queuedCycle: true));
      }
    }
  }

  Future<void> notifyInspectionFinalized() {
    return syncNow(trigger: SyncTrigger.inspectionFinalized);
  }

  void setConnectivityAvailable(bool available) {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer(connectivityDebounce, () {
      if (_disposed) return;
      final recovered = !_connectivityAvailable && available;
      _connectivityAvailable = available;
      if (recovered) {
        unawaited(syncNow(trigger: SyncTrigger.connectivityRecovered));
      } else if (!available) {
        _publish(
          _snapshot.copyWith(
            phase: SyncPhase.waitingForConnectivity,
            connectivityAvailable: false,
          ),
        );
      }
    });
  }

  void onAppResumed() {
    if (_disposed) return;
    _schedulePeriodic();
    unawaited(syncNow(trigger: SyncTrigger.periodic));
  }

  void onAppPaused() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _cancelRetryTimer();
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
    _isRunning = false;
    _queuedCycleRequested = false;
    _publish(_snapshot.copyWith(phase: SyncPhase.stopped));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    stop();
    _disposed = true;
    await _controller.close();
  }

  Future<void> _runPullOnly(
    SyncTrigger trigger,
    _SyncPermissions permissions,
  ) async {
    if (!permissions.canPull || _isRunning) return;
    _isRunning = true;
    final startedAt = clock.now();
    try {
      final result = await workerFactory().syncNow(canPush: false);
      await _finishCycle(result, trigger, permissions, startedAt: startedAt);
    } catch (error, stackTrace) {
      final category = errorClassifier.classify(error);
      AppLogger.warning(
        'Sync pull-only falló: category=${category.name}',
        error,
        stackTrace,
      );
      await _finishFailure(
        category,
        trigger,
        permissions,
        startedAt: startedAt,
        error: error,
      );
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _finishCycle(
    SyncWorkerResult result,
    SyncTrigger trigger,
    _SyncPermissions permissions, {
    required DateTime startedAt,
  }) async {
    final now = clock.now();
    final queue = await queueStorage.pendingOperations();
    final pendingCount = queue.length;
    final failedCount = queue.where((item) => item.lastError != null).length;
    final conflictCount = queue.where((item) => item.isConflict).length;
    final requiresAttention = queue.where(_requiresAttention).length;
    final retryAt = _nextRetryAt(queue);
    final duration = now.difference(startedAt);
    final phase = _phaseForResult(
      result,
      pendingCount: pendingCount,
      failedCount: failedCount,
      conflictCount: conflictCount,
      permissions: permissions,
    );
    final lastQueueError = queue
        .map((item) => item.lastError)
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .firstOrNull;
    final category = result.error != null
        ? errorClassifier.classify(result.error!)
        : lastQueueError == null
        ? null
        : errorClassifier.classify(StateError(lastQueueError));
    final diagnostics = _snapshot.diagnostics.recordCycle(
      phase: phase,
      duration: duration,
      pending: pendingCount,
      conflicts: conflictCount,
      retried: trigger == SyncTrigger.retry,
      now: now,
    );

    _publish(
      SyncStatusSnapshot(
        phase: phase,
        startedAt: startedAt,
        finishedAt: now,
        lastSuccessfulSyncAt: phase == SyncPhase.synchronized
            ? now
            : _snapshot.lastSuccessfulSyncAt,
        lastAttemptAt: now,
        uploadedCount: result.processed,
        downloadedCount: result.downloaded,
        appliedCount: result.applied,
        failedCount: failedCount,
        pendingCount: pendingCount,
        conflictCount: conflictCount,
        requiresAttentionCount: requiresAttention,
        retryScheduledAt: retryAt,
        connectivityAvailable: _connectivityAvailable,
        authenticated: permissions.authenticated,
        profileActive: permissions.profileActive,
        canPush: permissions.canPush,
        canPull: permissions.canPull,
        lastErrorCategory: category,
        lastErrorAt: category == null ? null : now,
        duration: duration,
        trigger: trigger,
        role: permissions.role,
        diagnostics: diagnostics,
      ),
    );
    _scheduleRetryIfNeeded(retryAt);
    AppLogger.info(
      'Sync fin trigger=${trigger.name} phase=${phase.name} '
      'duration_ms=${duration.inMilliseconds} uploaded=${result.processed} '
      'downloaded=${result.downloaded} applied=${result.applied} '
      'pending=$pendingCount failed=$failedCount conflicts=$conflictCount',
    );
  }

  Future<void> _finishFailure(
    SyncErrorCategory category,
    SyncTrigger trigger,
    _SyncPermissions permissions, {
    required DateTime startedAt,
    required Object error,
  }) async {
    final now = clock.now();
    final queue = await queueStorage.pendingOperations();
    final retryAt = errorClassifier.isTransient(category)
        ? _nextRetryAt(queue)
        : null;
    final phase = switch (category) {
      SyncErrorCategory.permission => SyncPhase.permissionDenied,
      SyncErrorCategory.authentication => SyncPhase.waitingForAuthentication,
      SyncErrorCategory.conflict => SyncPhase.conflict,
      SyncErrorCategory.network => SyncPhase.waitingForConnectivity,
      _ => SyncPhase.transientFailure,
    };
    final duration = now.difference(startedAt);
    final pendingCount = queue.length;
    final conflictCount = queue.where((item) => item.isConflict).length;
    final failedCount = queue.where((item) => item.lastError != null).length;
    final diagnostics = _snapshot.diagnostics.recordCycle(
      phase: phase,
      duration: duration,
      pending: pendingCount,
      conflicts: conflictCount,
      retried: trigger == SyncTrigger.retry,
      now: now,
    );

    _publish(
      _baseSnapshot(
        phase: phase,
        trigger: trigger,
        startedAt: startedAt,
        finishedAt: now,
        lastAttemptAt: now,
        pendingCount: pendingCount,
        failedCount: failedCount,
        conflictCount: conflictCount,
        requiresAttentionCount: queue.where(_requiresAttention).length,
        retryScheduledAt: retryAt,
        permissions: permissions,
        lastErrorCategory: category,
        lastErrorAt: now,
        duration: duration,
        diagnostics: diagnostics,
      ),
    );
    _scheduleRetryIfNeeded(retryAt);
  }

  SyncPhase _phaseForResult(
    SyncWorkerResult result, {
    required int pendingCount,
    required int failedCount,
    required int conflictCount,
    required _SyncPermissions permissions,
  }) {
    if (!permissions.authenticated) return SyncPhase.waitingForAuthentication;
    if (!permissions.profileActive) return SyncPhase.permissionDenied;
    if (conflictCount > 0 || result.status == SyncWorkerStatus.conflict) {
      return SyncPhase.conflict;
    }
    if (failedCount > 0 || result.status == SyncWorkerStatus.partialFailure) {
      return SyncPhase.partialSuccess;
    }
    if (pendingCount > 0) {
      return permissions.canPush
          ? SyncPhase.pendingChanges
          : SyncPhase.permissionDenied;
    }
    if (result.status == SyncWorkerStatus.unavailable) {
      return SyncPhase.unavailable;
    }
    return SyncPhase.synchronized;
  }

  SyncStatusSnapshot _baseSnapshot({
    required SyncPhase phase,
    required SyncTrigger trigger,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? lastAttemptAt,
    int pendingCount = 0,
    int failedCount = 0,
    int conflictCount = 0,
    int requiresAttentionCount = 0,
    DateTime? retryScheduledAt,
    required _SyncPermissions permissions,
    SyncErrorCategory? lastErrorCategory,
    DateTime? lastErrorAt,
    Duration? duration,
    SyncDiagnostics? diagnostics,
  }) {
    return _snapshot.copyWith(
      phase: phase,
      startedAt: startedAt,
      finishedAt: finishedAt,
      lastAttemptAt: lastAttemptAt,
      pendingCount: pendingCount,
      failedCount: failedCount,
      conflictCount: conflictCount,
      requiresAttentionCount: requiresAttentionCount,
      retryScheduledAt: retryScheduledAt,
      connectivityAvailable: _connectivityAvailable,
      authenticated: permissions.authenticated,
      profileActive: permissions.profileActive,
      canPush: permissions.canPush,
      canPull: permissions.canPull,
      lastErrorCategory: lastErrorCategory,
      lastErrorAt: lastErrorAt,
      duration: duration,
      trigger: trigger,
      role: permissions.role,
      diagnostics: diagnostics,
      clearRetry: retryScheduledAt == null,
      clearError: lastErrorCategory == null,
    );
  }

  _SyncPermissions _permissions(UserProfile? profile, AuthStatus authStatus) {
    final authenticated =
        authStatus == AuthStatus.authenticated && profile != null;
    final profileActive = authenticated && profile.active;
    return _SyncPermissions(
      authenticated: authenticated,
      profileActive: profileActive,
      canPush: profileActive && permissionService.canPushSync(profile),
      canPull: profileActive && permissionService.canPullSync(profile),
      role: profile?.role,
    );
  }

  DateTime? _nextRetryAt(List<SyncQueueEntry> queue) {
    final retryDates =
        queue.map((item) => item.nextAttemptAt).whereType<DateTime>().toList()
          ..sort();
    return retryDates.isEmpty ? null : retryDates.first;
  }

  bool _requiresAttention(SyncQueueEntry entry) {
    return entry.isConflict || entry.attempts >= 5;
  }

  void _schedulePeriodic() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(periodicInterval, (_) {
      unawaited(syncNow(trigger: SyncTrigger.periodic));
    });
  }

  void _scheduleRetryIfNeeded(DateTime? retryAt) {
    _cancelRetryTimer();
    if (retryAt == null || _disposed) return;
    final delay = retryAt.difference(clock.now());
    _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      unawaited(syncNow(trigger: SyncTrigger.retry));
    });
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _publish(SyncStatusSnapshot snapshot, {bool persist = true}) {
    _snapshot = snapshot;
    if (!_controller.isClosed) _controller.add(snapshot);
    if (persist) {
      unawaited(_persistSnapshot(snapshot));
    }
    AppLogger.info(
      'Sync estado phase=${snapshot.phase.name} pending=${snapshot.pendingCount} '
      'failed=${snapshot.failedCount} conflicts=${snapshot.conflictCount}',
    );
  }

  Future<void> _persistSnapshot(SyncStatusSnapshot snapshot) async {
    try {
      await statusStorage?.save(snapshot);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Sync no pudo persistir estado local',
        error,
        stackTrace,
      );
    }
  }
}

class _SyncPermissions {
  final bool authenticated;
  final bool profileActive;
  final bool canPush;
  final bool canPull;
  final UserRole? role;

  const _SyncPermissions({
    required this.authenticated,
    required this.profileActive,
    required this.canPush,
    required this.canPull,
    required this.role,
  });
}
