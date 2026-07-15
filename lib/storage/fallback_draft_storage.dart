import '../models/draft_data.dart';
import 'draft_storage.dart';
import 'migration/migration_target.dart';

class FallbackDraftStorage implements DraftStorage {
  static const String migrationKey = 'v1_shared_preferences';

  final DraftStorage localStorage;
  final DraftStorage legacyStorage;
  final MigrationTarget migrationTarget;

  const FallbackDraftStorage({
    required this.localStorage,
    required this.legacyStorage,
    required this.migrationTarget,
  });

  @override
  Future<void> guardarBorrador(DraftData borrador) async {
    if (await _migrationCompleted()) {
      return localStorage.guardarBorrador(borrador);
    }

    return legacyStorage.guardarBorrador(borrador);
  }

  @override
  Future<DraftData> cargarBorrador(String seleccionLinea) async {
    if (await _migrationCompleted()) {
      return localStorage.cargarBorrador(seleccionLinea);
    }

    return legacyStorage.cargarBorrador(seleccionLinea);
  }

  @override
  Future<void> borrarBorrador() async {
    if (await _migrationCompleted()) {
      return localStorage.borrarBorrador();
    }

    return legacyStorage.borrarBorrador();
  }

  Future<bool> _migrationCompleted() async {
    try {
      return await migrationTarget.isMigrationCompleted(migrationKey);
    } catch (_) {
      return false;
    }
  }
}
