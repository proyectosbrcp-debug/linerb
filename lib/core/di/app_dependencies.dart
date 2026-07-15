import '../../controllers/history_controller.dart';
import '../../controllers/inspection_registration_controller.dart';
import '../../controllers/progress_controller.dart';
import '../../controllers/selection_line_controller.dart';
import '../../repositories/catalog_repository.dart';
import '../../repositories/draft_repository.dart';
import '../../repositories/inspection_repository.dart';
import '../../storage/catalog_cache_storage.dart';
import '../../storage/draft_storage.dart';
import '../../storage/inspection_storage.dart';
import '../../storage/shared_preferences_storage.dart';

class AppDependencies {
  static const SharedPreferencesStorage sharedPreferencesStorage =
      SharedPreferencesStorage();

  static const InspectionStorage inspectionStorage = sharedPreferencesStorage;
  static const DraftStorage draftStorage = sharedPreferencesStorage;
  static const CatalogCacheStorage catalogCacheStorage =
      sharedPreferencesStorage;

  static const InspectionRepository inspectionRepository =
      CurrentInspectionRepository(storage: inspectionStorage);
  static const DraftRepository draftRepository = CurrentDraftRepository(
    storage: draftStorage,
  );
  static const CatalogRepository catalogRepository = CurrentCatalogRepository(
    storage: catalogCacheStorage,
  );

  static SelectionLineController selectionLineController() {
    return SelectionLineController(catalogRepository: catalogRepository);
  }

  static InspectionRegistrationController inspectionRegistrationController() {
    return const InspectionRegistrationController(
      draftRepository: draftRepository,
    );
  }

  static HistoryController historyController() {
    return HistoryController(inspectionRepository: inspectionRepository);
  }

  static const ProgressController progressController = ProgressController(
    inspectionRepository: inspectionRepository,
  );
}
