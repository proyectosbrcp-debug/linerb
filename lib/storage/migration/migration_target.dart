import '../../models/draft_data.dart';
import '../../models/inspeccion.dart';

abstract class MigrationTarget {
  Future<bool> isMigrationCompleted(String key);

  Future<void> markMigrationCompleted(String key);

  Future<bool> saveLegacyInspection({
    required String id,
    required String sourceKey,
    required int createdOrder,
    required Inspeccion inspeccion,
  });

  Future<void> saveMigratedDraft(DraftData draft);
}
