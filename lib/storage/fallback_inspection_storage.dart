import '../models/inspeccion.dart';
import '../models/hallazgo_inspeccion.dart';
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
  Future<InspectionHistoryPage> cargarHistorialPage({
    String? cursor,
    int limit = 30,
  }) async {
    if (await _migrationCompleted()) {
      return localStorage.cargarHistorialPage(cursor: cursor, limit: limit);
    }

    return legacyStorage.cargarHistorialPage(cursor: cursor, limit: limit);
  }

  @override
  Future<void> agregarInspeccionHistorial(Inspeccion inspeccion) async {
    if (await _migrationCompleted()) {
      return localStorage.agregarInspeccionHistorial(inspeccion);
    }

    return legacyStorage.agregarInspeccionHistorial(inspeccion);
  }

  @override
  Future<void> agregarInspeccionCompleta(
    Inspeccion inspeccion,
    List<HallazgoInspeccion> hallazgos,
  ) async {
    if (await _migrationCompleted()) {
      return localStorage.agregarInspeccionCompleta(inspeccion, hallazgos);
    }

    return legacyStorage.agregarInspeccionCompleta(inspeccion, hallazgos);
  }

  Future<bool> _migrationCompleted() async {
    try {
      return await migrationTarget.isMigrationCompleted(migrationKey);
    } catch (_) {
      return false;
    }
  }
}
