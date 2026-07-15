import '../../controllers/dashboard_controller.dart';
import '../../controllers/history_controller.dart';
import '../../controllers/inspection_registration_controller.dart';
import '../../controllers/progress_controller.dart';
import '../../controllers/selection_line_controller.dart';
import '../../core/runtime/app_runtime_initializer.dart';
import '../../repositories/catalog_repository.dart';
import '../../repositories/dashboard_repository.dart';
import '../../repositories/draft_repository.dart';
import '../../repositories/inspection_repository.dart';
import '../../storage/catalog_cache_storage.dart';
import '../../storage/draft_storage.dart';
import '../../storage/fallback_draft_storage.dart';
import '../../storage/fallback_inspection_storage.dart';
import '../../storage/diagnostics/local_diagnostic_service.dart';
import '../../storage/integrity/local_data_integrity_service.dart';
import '../../storage/inspection_storage.dart';
import '../../storage/local/linerb_database.dart';
import '../../storage/local/local_database_storage.dart';
import '../../storage/migration/v1_data_migration_service.dart';
import '../../storage/shared_preferences_storage.dart';

class AppDependencies {
  static final LinerbDatabase linerbDatabase = LinerbDatabase();
  static final LocalDatabaseStorage localDatabaseStorage = LocalDatabaseStorage(
    database: linerbDatabase,
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
