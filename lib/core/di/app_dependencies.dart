import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/history_controller.dart';
import '../../controllers/inspection_registration_controller.dart';
import '../../controllers/progress_controller.dart';
import '../../controllers/selection_line_controller.dart';
import '../../core/runtime/app_runtime_initializer.dart';
import '../../core/time/app_clock.dart';
import '../../repositories/catalog_repository.dart';
import '../../repositories/dashboard_repository.dart';
import '../../repositories/draft_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/firebase_auth_repository.dart';
import '../../repositories/firestore_user_profile_repository.dart';
import '../../repositories/inspection_repository.dart';
import '../../repositories/remote/firestore_remote_sync_data_source.dart';
import '../../repositories/sync_repository.dart';
import '../../repositories/unavailable_auth_repository.dart';
import '../../repositories/unavailable_user_profile_repository.dart';
import '../../repositories/user_profile_repository.dart';
import '../../services/device_identity_service.dart';
import '../../services/local_photo_service.dart';
import '../../services/automatic_sync_coordinator.dart';
import '../../services/permission_service.dart';
import '../../services/remote_sync_applier.dart';
import '../../services/sync_worker.dart';
import '../../storage/auth_session_storage.dart';
import '../../storage/catalog_cache_storage.dart';
import '../../storage/draft_storage.dart';
import '../../storage/fallback_draft_storage.dart';
import '../../storage/fallback_inspection_storage.dart';
import '../../storage/diagnostics/local_diagnostic_service.dart';
import '../../storage/integrity/local_data_integrity_service.dart';
import '../../storage/inspection_storage.dart';
import '../../storage/local/linerb_database.dart';
import '../../storage/local/local_database_storage.dart';
import '../../storage/local/local_sync_queue_storage.dart';
import '../../storage/local/local_sync_metadata_storage.dart';
import '../../storage/local/local_sync_status_storage.dart';
import '../../storage/migration/v1_data_migration_service.dart';
import '../../storage/shared_preferences_auth_session_storage.dart';
import '../../storage/shared_preferences_storage.dart';

class AppDependencies {
  static const Clock clock = SystemClock();
  static final DeviceIdentityService deviceIdentityService =
      DeviceIdentityService(clock: clock.now);
  static const AuthSessionStorage authSessionStorage =
      SharedPreferencesAuthSessionStorage();
  static final AuthRepository authRepository = Firebase.apps.isEmpty
      ? const UnavailableAuthRepository()
      : FirebaseAuthRepository();
  static final UserProfileRepository userProfileRepository =
      Firebase.apps.isEmpty
      ? const UnavailableUserProfileRepository()
      : FirestoreUserProfileRepository(firestore: FirebaseFirestore.instance);
  static final AuthController authController = AuthController(
    authRepository: authRepository,
    userProfileRepository: userProfileRepository,
    sessionStorage: authSessionStorage,
  );
  static final LinerbDatabase linerbDatabase = LinerbDatabase();
  static final LocalSyncQueueStorage syncQueueStorage = LocalSyncQueueStorage(
    database: linerbDatabase,
    clock: clock,
  );
  static final LocalDatabaseStorage localDatabaseStorage = LocalDatabaseStorage(
    database: linerbDatabase,
    clock: clock,
    deviceIdProvider: deviceIdentityService.deviceId,
    userIdProvider: () async => authController.currentUserId,
    syncQueueStorage: syncQueueStorage,
  );
  static final LocalPhotoService localPhotoService = LocalPhotoService(
    clock: clock,
  );
  static final SyncRepository syncRepository = LocalSyncRepository(
    queueStorage: syncQueueStorage,
  );
  static final LocalSyncMetadataStorage syncMetadataStorage =
      LocalSyncMetadataStorage(database: linerbDatabase);
  static final RemoteSyncApplier remoteSyncApplier = RemoteSyncApplier(
    database: linerbDatabase,
  );
  static final LocalSyncStatusStorage syncStatusStorage =
      LocalSyncStatusStorage(database: linerbDatabase);
  static FirestoreRemoteSyncDataSource? get remoteSyncDataSource {
    if (Firebase.apps.isEmpty) return null;
    return FirestoreRemoteSyncDataSource(firestore: FirebaseFirestore.instance);
  }

  static SyncWorker syncWorker() {
    return SyncWorker(
      queueStorage: syncQueueStorage,
      metadataStorage: syncMetadataStorage,
      remoteDataSource: remoteSyncDataSource,
      remoteSyncApplier: remoteSyncApplier,
      clock: clock,
    );
  }

  static final AutomaticSyncCoordinator automaticSyncCoordinator =
      AutomaticSyncCoordinator(
        workerFactory: syncWorker,
        queueStorage: syncQueueStorage,
        authController: authController,
        permissionService: const PermissionService(),
        statusStorage: syncStatusStorage,
        runtimeStatusProvider: () => runtimeStatus,
        clock: clock,
      );

  static const SharedPreferencesStorage sharedPreferencesStorage =
      SharedPreferencesStorage();

  static final InspectionStorage inspectionStorage = FallbackInspectionStorage(
    localStorage: localDatabaseStorage,
    legacyStorage: sharedPreferencesStorage,
    migrationTarget: localDatabaseStorage,
  );
  static final DraftStorage draftStorage = FallbackDraftStorage(
    localStorage: localDatabaseStorage,
    legacyStorage: sharedPreferencesStorage,
    migrationTarget: localDatabaseStorage,
  );
  static const CatalogCacheStorage catalogCacheStorage =
      sharedPreferencesStorage;

  static final InspectionRepository inspectionRepository =
      CurrentInspectionRepository(storage: inspectionStorage);
  static final DraftRepository draftRepository = CurrentDraftRepository(
    storage: draftStorage,
  );
  static const CatalogRepository catalogRepository = CurrentCatalogRepository(
    storage: catalogCacheStorage,
  );
  static final DashboardRepository dashboardRepository =
      SqliteDashboardRepository(
        database: linerbDatabase,
        catalogRepository: catalogRepository,
      );
  static final V1DataMigrationService v1DataMigrationService =
      V1DataMigrationService(target: localDatabaseStorage);
  static final LocalDataIntegrityService localDataIntegrityService =
      LocalDataIntegrityService(database: linerbDatabase);
  static final AppRuntimeInitializer runtimeInitializer = AppRuntimeInitializer(
    openDatabase: () async {
      await linerbDatabase.open();
    },
    migrate: () async {
      await v1DataMigrationService.migrate();
      await localDatabaseStorage.hydrateMemoryFromDatabase();
    },
  );
  static final LocalDiagnosticService localDiagnosticService =
      LocalDiagnosticService(
        database: linerbDatabase,
        runtimeInitializer: runtimeInitializer,
      );

  static RuntimeInitializationStatus get runtimeStatus {
    return runtimeInitializer.status;
  }

  static Future<RuntimeInitializationResult> initialize() {
    return runtimeInitializer.initialize();
  }

  static SelectionLineController selectionLineController() {
    return SelectionLineController(catalogRepository: catalogRepository);
  }

  static InspectionRegistrationController inspectionRegistrationController() {
    return InspectionRegistrationController(draftRepository: draftRepository);
  }

  static HistoryController historyController() {
    return HistoryController(inspectionRepository: inspectionRepository);
  }

  static final ProgressController progressController = ProgressController(
    inspectionRepository: inspectionRepository,
  );

  static DashboardController dashboardController() {
    return DashboardController(
      repository: dashboardRepository,
      clock: DateTime.now,
    );
  }
}
