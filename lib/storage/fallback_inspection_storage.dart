import '../models/inspeccion.dart';
import 'inspection_storage.dart';
import 'migration/migration_target.dart';

class FallbackInspectionStorage implements InspectionStorage {
  static const String migrationKey = 'v1_shared_preferences';

  final InspectionStorage localStorage;
  final InspectionStorage legacyStorage;
  final MigrationTarget migrationTarget;

  const FallbackInspectionStorage({
    required this.localStorage,
    required this.legacyStorage,
    required this.migrationTarget,
  });

  @override
  List<Inspeccion> obtenerInspeccionesMemoria() {
    return localStorage.obtenerInspeccionesMemoria();
  }

  @override
  void agregarInspeccionMemoria(Inspeccion inspeccion) {
    localStorage.agregarInspeccionMemoria(inspeccion);
  }

  @override
  DateTime? ultimaInspeccionMemoria(String linea) {
    return localStorage.ultimaInspeccionMemoria(linea);
  }

  @override
  Future<List<Inspeccion>> cargarHistorial() async {
    if (await _migrationCompleted()) {
      return localStorage.cargarHistorial();
    }

    return legacyStorage.cargarHistorial();
  }

  @override
  Future<void> agregarInspeccionHistorial(Inspeccion inspeccion) async {
    if (await _migrationCompleted()) {
      return localStorage.agregarInspeccionHistorial(inspeccion);
    }

    return legacyStorage.agregarInspeccionHistorial(inspeccion);
  }

  Future<bool> _migrationCompleted() async {
    try {
      return await migrationTarget.isMigrationCompleted(migrationKey);
    } catch (_) {
      return false;
    }
  }
}
