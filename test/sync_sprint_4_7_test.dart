import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/controllers/auth_controller.dart';
import 'package:linerb/core/runtime/app_runtime_initializer.dart';
import 'package:linerb/core/time/app_clock.dart';
import 'package:linerb/models/auth_models.dart';
import 'package:linerb/models/sync_models.dart';
import 'package:linerb/models/sync_status_snapshot.dart';
import 'package:linerb/models/user_profile.dart';
import 'package:linerb/pages/sync/sync_status_page.dart';
import 'package:linerb/repositories/auth_repository.dart';
import 'package:linerb/repositories/sync_repository.dart';
import 'package:linerb/repositories/user_profile_repository.dart';
import 'package:linerb/services/automatic_sync_coordinator.dart';
import 'package:linerb/services/permission_service.dart';
import 'package:linerb/services/sync_error_classifier.dart';
import 'package:linerb/services/sync_retry_policy.dart';
import 'package:linerb/services/sync_worker.dart';
import 'package:linerb/storage/auth_session_storage.dart';
import 'package:linerb/storage/sync_metadata_storage.dart';
import 'package:linerb/storage/sync_queue_storage.dart';
import 'package:linerb/storage/sync_status_storage.dart';
import 'package:linerb/widgets/sync_status_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sync Sprint 4.7 estado central', () {
    test('define actualizado solo sin pendientes, fallos ni conflictos', () {
      final snapshot = SyncStatusSnapshot(
        phase: SyncPhase.synchronized,
        authenticated: true,
        profileActive: true,
        lastSuccessfulSyncAt: DateTime(2026, 7, 31),
      );

      expect(snapshot.isTrulySynchronized, isTrue);
      expect(snapshot.copyWith(pendingCount: 1).isTrulySynchronized, isFalse);
      expect(snapshot.copyWith(failedCount: 1).isTrulySynchronized, isFalse);
      expect(snapshot.copyWith(conflictCount: 1).isTrulySynchronized, isFalse);
      expect(
        snapshot.copyWith(authenticated: false).isTrulySynchronized,
        isFalse,
      );
    });

    test('transición syncing a synchronized con cola vacía', () async {
      final harness = _Harness(authenticatedRole: UserRole.inspector);

      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      expect(harness.coordinator.snapshot.phase, SyncPhase.synchronized);
      expect(harness.coordinator.snapshot.isTrulySynchronized, isTrue);
    });

    test('estado con pendientes no afirma actualizado', () async {
      final harness = _Harness(authenticatedRole: UserRole.inspector);
      harness.queue.entries.add(_entry('i1'));
      harness.remote.failPush = true;

      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      expect(harness.coordinator.snapshot.phase, SyncPhase.partialSuccess);
      expect(harness.coordinator.snapshot.pendingCount, 1);
      expect(harness.coordinator.snapshot.isTrulySynchronized, isFalse);
    });

    test('estado sin conexión espera recuperación', () async {
      final harness = _Harness(authenticatedRole: UserRole.inspector);

      harness.coordinator.setConnectivityAvailable(false);
      await Future<void>.delayed(Duration.zero);
      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      expect(
        harness.coordinator.snapshot.phase,
        SyncPhase.waitingForConnectivity,
      );
    });

    test('estado sin sesión requiere autenticación', () async {
      final harness = _Harness();

      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      expect(
        harness.coordinator.snapshot.phase,
        SyncPhase.waitingForAuthentication,
      );
    });

    test('perfil inactivo queda en permiso insuficiente', () async {
      final harness = _Harness(
        authenticatedRole: UserRole.inspector,
        active: false,
      );

      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      expect(harness.coordinator.snapshot.phase, SyncPhase.permissionDenied);
    });

    test('viewer con pendientes no hace push y conserva cola', () async {
      final harness = _Harness(authenticatedRole: UserRole.viewer);
      harness.queue.entries.add(_entry('i1'));

      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      expect(harness.remote.pushCount, 0);
      expect(harness.queue.entries, hasLength(1));
      expect(harness.coordinator.snapshot.phase, SyncPhase.permissionDenied);
    });

    test('conflicto pendiente evita estado actualizado', () async {
      final harness = _Harness(authenticatedRole: UserRole.supervisor);
      harness.queue.entries.add(_entry('i1', isConflict: true));

      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      expect(harness.coordinator.snapshot.phase, SyncPhase.conflict);
      expect(harness.coordinator.snapshot.conflictCount, 1);
    });

    test('operación atascada aumenta contador requiresAttention', () async {
      final harness = _Harness(authenticatedRole: UserRole.viewer);
      harness.queue.entries.add(_entry('i1', attempts: 5));

      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      expect(harness.coordinator.snapshot.requiresAttentionCount, 1);
    });

    test('sincronización manual no inicia ciclos paralelos', () async {
      final harness = _Harness(authenticatedRole: UserRole.inspector);
      harness.queue.entries.add(_entry('i1'));
      harness.remote.delay = const Duration(milliseconds: 40);

      await Future.wait([
        harness.coordinator.syncNow(trigger: SyncTrigger.manual),
        harness.coordinator.syncNow(trigger: SyncTrigger.manual),
      ]);

      expect(harness.remote.syncEntrances, 1);
    });

    test(
      'solicitud concurrente dispara como maximo un ciclo adicional',
      () async {
        final harness = _Harness(authenticatedRole: UserRole.inspector);
        harness.queue.entries.add(_entry('i1'));
        harness.remote.delay = const Duration(milliseconds: 40);

        final firstCycle = harness.coordinator.syncNow(
          trigger: SyncTrigger.manual,
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        harness.queue.entries.add(_entry('i2'));
        await harness.coordinator.syncNow(
          trigger: SyncTrigger.inspectionFinalized,
        );
        await harness.coordinator.syncNow(trigger: SyncTrigger.periodic);
        await firstCycle;
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(harness.remote.pushCount, 2);
        expect(harness.remote.syncEntrances, 2);
        expect(harness.queue.entries, isEmpty);
      },
    );

    test('logout detiene el coordinador', () {
      final harness = _Harness(authenticatedRole: UserRole.inspector);

      harness.coordinator.stop();

      expect(harness.coordinator.snapshot.phase, SyncPhase.stopped);
    });

    test(
      'reinicio convierte estado syncing persistido en fallo transitorio',
      () async {
        final storage = _StatusStorage(
          restored: SyncStatusSnapshot(
            phase: SyncPhase.syncing,
            authenticated: true,
            profileActive: true,
            lastAttemptAt: DateTime(2026, 7, 31, 11),
          ),
        );
        final harness = _Harness(
          authenticatedRole: UserRole.inspector,
          statusStorage: storage,
        );

        await harness.coordinator.restore();

        expect(harness.coordinator.snapshot.phase, SyncPhase.transientFailure);
      },
    );

    test('dispose cierra recursos sin lanzar', () async {
      final harness = _Harness(authenticatedRole: UserRole.inspector);

      await harness.coordinator.dispose();

      expect(harness.coordinator.snapshot.phase, SyncPhase.stopped);
    });
  });

  group('Sync Sprint 4.7 errores y reintentos', () {
    test('backoff exponencial con jitter determinista', () {
      final policy = SyncRetryPolicy(jitter: (_) => const Duration(seconds: 3));

      expect(policy.delayForAttempt(1), const Duration(seconds: 33));
      expect(policy.delayForAttempt(2), const Duration(seconds: 63));
      expect(policy.delayForAttempt(3), const Duration(seconds: 123));
      expect(policy.delayForAttempt(4), const Duration(minutes: 5, seconds: 3));
    });

    test('reset lógico tras éxito deja cola vacía y sin retry', () async {
      final harness = _Harness(authenticatedRole: UserRole.inspector);
      harness.queue.entries.add(_entry('i1', attempts: 2));

      await harness.coordinator.syncNow(trigger: SyncTrigger.retry);

      expect(harness.queue.entries, isEmpty);
      expect(harness.coordinator.snapshot.retryScheduledAt, isNull);
      expect(harness.coordinator.snapshot.phase, SyncPhase.synchronized);
    });

    test('clasifica permission-denied sin exponer código técnico', () {
      const classifier = SyncErrorClassifier();

      final category = classifier.classify(StateError('permission-denied'));
      final message = classifier.friendlyMessage(category);

      expect(category, SyncErrorCategory.permission);
      expect(message, isNot(contains('permission-denied')));
    });
  });

  group('Sync Sprint 4.7 roles y etiquetas', () {
    test(
      'administrator supervisor e inspector hacen push y pull permitido',
      () async {
        for (final role in const [
          UserRole.administrator,
          UserRole.supervisor,
          UserRole.inspector,
        ]) {
          final harness = _Harness(authenticatedRole: role);
          harness.queue.entries.add(_entry('i-${role.name}'));

          await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

          expect(harness.remote.pushCount, 1);
          expect(harness.coordinator.snapshot.canPush, isTrue);
          expect(harness.coordinator.snapshot.canPull, isTrue);
        }
      },
    );

    test('viewer nunca hace push y no descarta pendientes', () async {
      final harness = _Harness(authenticatedRole: UserRole.viewer);
      harness.queue.entries.add(_entry('viewer-old'));

      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      expect(harness.remote.pushCount, 0);
      expect(harness.queue.entries, hasLength(1));
      expect(harness.coordinator.snapshot.isTrulySynchronized, isFalse);
    });

    test('SyncStatusIndicator no muestra Actualizado sin exito real', () {
      final valid = SyncStatusSnapshot(
        phase: SyncPhase.synchronized,
        authenticated: true,
        profileActive: true,
        lastSuccessfulSyncAt: DateTime(2026, 7, 31),
      );

      expect(syncStatusLabel(valid), 'Actualizado');
      expect(
        syncStatusLabel(
          const SyncStatusSnapshot(
            phase: SyncPhase.synchronized,
            authenticated: true,
            profileActive: true,
          ),
        ),
        isNot('Actualizado'),
      );
      expect(
        syncStatusLabel(valid.copyWith(pendingCount: 1)),
        isNot('Actualizado'),
      );
      expect(
        syncStatusLabel(valid.copyWith(failedCount: 1)),
        isNot('Actualizado'),
      );
      expect(
        syncStatusLabel(valid.copyWith(conflictCount: 1)),
        isNot('Actualizado'),
      );
    });

    test('SyncStatusIndicator cubre estados visibles principales', () {
      expect(
        syncStatusLabel(const SyncStatusSnapshot(phase: SyncPhase.syncing)),
        'Sincronizando...',
      );
      expect(
        syncStatusLabel(
          const SyncStatusSnapshot(
            phase: SyncPhase.pendingChanges,
            pendingCount: 3,
          ),
        ),
        '3 cambios pendientes',
      );
      expect(
        syncStatusLabel(
          const SyncStatusSnapshot(phase: SyncPhase.waitingForConnectivity),
        ),
        contains('Sin conex'),
      );
      expect(
        syncStatusLabel(
          const SyncStatusSnapshot(phase: SyncPhase.waitingForAuthentication),
        ),
        contains('requerida'),
      );
      expect(
        syncStatusLabel(
          const SyncStatusSnapshot(phase: SyncPhase.transientFailure),
        ),
        'Error temporal',
      );
      expect(
        syncStatusLabel(
          const SyncStatusSnapshot(phase: SyncPhase.permissionDenied),
        ),
        'Permiso insuficiente',
      );
      expect(
        syncStatusLabel(const SyncStatusSnapshot(phase: SyncPhase.conflict)),
        'Conflicto pendiente',
      );
    });
  });

  group('Sync Sprint 4.7 estrÃ©s moderado', () {
    test(
      'procesa 100 inspecciones con hallazgos, fallos parciales y sin duplicar',
      () async {
        final harness = _Harness(authenticatedRole: UserRole.inspector);

        for (var inspection = 0; inspection < 100; inspection++) {
          final inspectionId = 'i-$inspection';
          harness.queue.entries.add(_entry(inspectionId));
        }
        for (var inspection = 0; inspection < 100; inspection++) {
          final inspectionId = 'i-$inspection';
          for (var finding = 0; finding < 3; finding++) {
            final findingId = 'f-$inspection-$finding';
            harness.queue.entries.add(
              _entry(
                findingId,
                entityType: SyncEntityType.finding,
                inspectionId: inspectionId,
              ),
            );
          }
        }
        harness.remote.failEntityIds.addAll({
          'f-0-1',
          'f-25-1',
          'f-50-1',
          'f-75-1',
        });

        await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

        final remainingIds = harness.queue.entries
            .map((entry) => entry.entityId)
            .toSet();
        expect(harness.coordinator.snapshot.phase, SyncPhase.partialSuccess);
        expect(harness.coordinator.snapshot.uploadedCount, 396);
        expect(harness.coordinator.snapshot.pendingCount, 4);
        expect(harness.coordinator.snapshot.failedCount, 4);
        expect(remainingIds, harness.remote.failEntityIds);
        expect(harness.queue.entries, hasLength(remainingIds.length));
      },
    );
  });

  group('Sync Sprint 4.7 widgets', () {
    testWidgets('indicador muestra Sincronizando con texto visible', (
      tester,
    ) async {
      final harness = _Harness(authenticatedRole: UserRole.inspector);
      harness.queue.entries.add(_entry('i1'));
      harness.remote.delay = const Duration(milliseconds: 40);

      final syncFuture = harness.coordinator.syncNow(
        trigger: SyncTrigger.manual,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [SyncStatusIndicator(coordinator: harness.coordinator)],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Sincronizando...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await syncFuture;
    });

    testWidgets('indicador muestra Actualizado', (tester) async {
      final harness = _Harness(authenticatedRole: UserRole.inspector);
      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [SyncStatusIndicator(coordinator: harness.coordinator)],
            ),
          ),
        ),
      );

      expect(find.text('Actualizado'), findsOneWidget);
    });

    testWidgets('indicador muestra pendientes', (tester) async {
      final harness = _Harness(authenticatedRole: UserRole.viewer);
      harness.queue.entries.add(_entry('i1'));
      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [SyncStatusIndicator(coordinator: harness.coordinator)],
            ),
          ),
        ),
      );

      expect(find.text('1 cambios por permisos'), findsOneWidget);
    });

    testWidgets('panel de detalle muestra botón y no expone código técnico', (
      tester,
    ) async {
      final harness = _Harness(authenticatedRole: UserRole.inspector);
      harness.queue.entries.add(_entry('i1', lastError: 'permission-denied'));
      harness.remote.failPush = true;
      await harness.coordinator.syncNow(trigger: SyncTrigger.manual);

      await tester.binding.setSurfaceSize(const Size(900, 1200));
      await tester.pumpWidget(
        MaterialApp(home: SyncStatusPage(coordinator: harness.coordinator)),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));

      expect(find.text('Sincronizar ahora'), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsNothing);
      expect(find.text('Pendientes'), findsOneWidget);
      harness.coordinator.stop();
    });
  });
}

class _Harness {
  final _Queue queue = _Queue();
  final _Remote remote = _Remote();
  final _Metadata metadata = _Metadata();
  final SyncStatusStorage? statusStorage;
  late final AuthController auth;
  late final AutomaticSyncCoordinator coordinator;

  _Harness({
    UserRole? authenticatedRole,
    bool active = true,
    this.statusStorage,
  }) {
    auth = AuthController(
      authRepository: _AuthRepository(),
      userProfileRepository: _UserProfileRepository(),
      sessionStorage: _AuthSessionStorage(),
    );
    if (authenticatedRole == null) {
      auth.state = const AuthState(status: AuthStatus.unauthenticated);
    } else {
      auth.state = AuthState(
        status: AuthStatus.authenticated,
        profile: _profile(authenticatedRole, active: active),
      );
    }

    coordinator = AutomaticSyncCoordinator(
      workerFactory: () => SyncWorker(
        queueStorage: queue,
        metadataStorage: metadata,
        remoteDataSource: remote,
        clock: const _FixedClock(),
        retryPolicy: SyncRetryPolicy(
          clock: const _FixedClock(),
          jitter: (_) => Duration.zero,
        ),
      ),
      queueStorage: queue,
      authController: auth,
      permissionService: const PermissionService(),
      statusStorage: statusStorage,
      runtimeStatusProvider: () => RuntimeInitializationStatus.ready,
      clock: const _FixedClock(),
      periodicInterval: const Duration(minutes: 1),
      connectivityDebounce: Duration.zero,
    );
  }
}

class _FixedClock implements Clock {
  const _FixedClock();

  @override
  DateTime now() => DateTime(2026, 7, 31, 12);
}

UserProfile _profile(UserRole role, {bool active = true}) {
  return UserProfile(
    uid: 'uid-$role',
    displayName: 'Operador',
    email: 'operador@linerb.local',
    role: role,
    active: active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

SyncQueueEntry _entry(
  String id, {
  int attempts = 0,
  String? lastError,
  bool isConflict = false,
  SyncEntityType entityType = SyncEntityType.inspection,
  String? inspectionId,
}) {
  final payload = <String, Object?>{'remote_version': 0};
  if (inspectionId != null) {
    payload['inspection_id'] = inspectionId;
  }

  return SyncQueueEntry(
    id: 'queue-$id',
    entityType: entityType,
    entityId: id,
    operation: SyncOperationType.create,
    payloadJson: jsonEncode(payload),
    attempts: attempts,
    nextAttemptAt: null,
    lastError: lastError,
    createdAt: DateTime(2026, 7, 31),
    updatedAt: DateTime(2026, 7, 31),
    isConflict: isConflict,
  );
}

class _Queue implements SyncQueueStorage {
  final entries = <SyncQueueEntry>[];

  @override
  Future<void> enqueue(SyncQueueOperation operation) async {}

  @override
  Future<bool> hasDuplicate(SyncQueueOperation operation) async => false;

  @override
  Future<void> incrementAttempts(String queueEntryId) async {
    final index = entries.indexWhere((entry) => entry.id == queueEntryId);
    entries[index] = _copy(
      entries[index],
      attempts: entries[index].attempts + 1,
    );
  }

  @override
  Future<void> markCompleted(String queueEntryId) async {
    entries.removeWhere((entry) => entry.id == queueEntryId);
  }

  @override
  Future<List<SyncQueueEntry>> pendingOperations() async => List.of(entries);

  @override
  Future<List<SyncQueueEntry>> pendingOperationsPage({
    required DateTime now,
    int limit = 100,
  }) async {
    final eligible = entries
        .where(
          (entry) =>
              entry.nextAttemptAt == null || !entry.nextAttemptAt!.isAfter(now),
        )
        .toList();
    return eligible.take(limit).toList();
  }

  @override
  Future<void> registerFailure(String queueEntryId, String error) async {
    final index = entries.indexWhere((entry) => entry.id == queueEntryId);
    entries[index] = _copy(entries[index], lastError: error);
  }

  @override
  Future<void> rescheduleRetry(
    String queueEntryId,
    DateTime nextAttemptAt,
  ) async {
    final index = entries.indexWhere((entry) => entry.id == queueEntryId);
    entries[index] = _copy(entries[index], nextAttemptAt: nextAttemptAt);
  }

  SyncQueueEntry _copy(
    SyncQueueEntry entry, {
    int? attempts,
    String? lastError,
    DateTime? nextAttemptAt,
  }) {
    return SyncQueueEntry(
      id: entry.id,
      entityType: entry.entityType,
      entityId: entry.entityId,
      operation: entry.operation,
      payloadJson: entry.payloadJson,
      attempts: attempts ?? entry.attempts,
      nextAttemptAt: nextAttemptAt ?? entry.nextAttemptAt,
      lastError: lastError ?? entry.lastError,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      isConflict: entry.isConflict,
    );
  }
}

class _Metadata implements SyncMetadataStorage {
  @override
  Future<SyncMetadata?> loadMetadata(
    SyncEntityType entityType,
    String entityId,
  ) async {
    return null;
  }

  @override
  Future<void> markConflict(
    SyncEntityType entityType,
    String entityId, {
    required String remotePayload,
  }) async {}

  @override
  Future<void> markSynced(
    SyncEntityType entityType,
    String entityId, {
    required int remoteVersion,
    required DateTime lastSyncAt,
  }) async {}

  @override
  Future<void> updateStatus(
    SyncEntityType entityType,
    String entityId,
    SyncStatus status,
  ) async {}
}

class _Remote implements RemoteSyncDataSource {
  bool failPush = false;
  Duration delay = Duration.zero;
  int pushCount = 0;
  int syncEntrances = 0;
  final failEntityIds = <String>{};

  @override
  Future<void> push(SyncQueueEntry operation) async {
    syncEntrances++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failEntityIds.contains(operation.entityId)) {
      throw StateError('fallo remoto');
    }
    if (failPush) throw StateError('fallo remoto');
    pushCount++;
  }

  @override
  Future<void> pushBatch(List<SyncQueueEntry> operations) async {
    syncEntrances++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (operations.any(
      (operation) => failEntityIds.contains(operation.entityId),
    )) {
      throw StateError('fallo remoto');
    }
    if (failPush) throw StateError('fallo remoto');
    pushCount += operations.length;
  }

  @override
  Future<void> createFinding(Map<String, Object?> payload) async {}

  @override
  Future<void> createInspection(Map<String, Object?> payload) async {}

  @override
  Future<void> deleteFinding(Map<String, Object?> payload) async {}

  @override
  Future<void> deleteInspection(Map<String, Object?> payload) async {}

  @override
  Future<RemoteChangeSet> fetchChanges({
    DateTime? since,
    RemoteSyncCursors? cursors,
  }) async {
    return const RemoteChangeSet(inspections: [], findings: [], cursor: null);
  }

  @override
  Future<List<Map<String, Object?>>> fetchFindingsForInspections(
    List<String> inspectionGlobalIds,
  ) async {
    return const [];
  }

  @override
  Future<void> updateFinding(Map<String, Object?> payload) async {}

  @override
  Future<void> updateInspection(Map<String, Object?> payload) async {}
}

class _AuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return const AuthUser(uid: 'uid');
  }

  @override
  Future<void> signOut() async {}
}

class _UserProfileRepository implements UserProfileRepository {
  @override
  Future<UserProfile?> findByUid(String uid) async => null;
}

class _AuthSessionStorage implements AuthSessionStorage {
  @override
  Future<void> clearLastValidProfile() async {}

  @override
  Future<UserProfile?> loadLastValidProfile() async => null;

  @override
  Future<void> saveLastValidProfile(UserProfile profile) async {}
}

class _StatusStorage implements SyncStatusStorage {
  SyncStatusSnapshot? restored;
  SyncStatusSnapshot? saved;

  _StatusStorage({this.restored});

  @override
  Future<SyncStatusSnapshot?> restore() async => restored;

  @override
  Future<void> save(SyncStatusSnapshot snapshot) async {
    saved = snapshot;
  }
}
