import '../models/inspeccion.dart';
import '../storage/inspection_storage.dart';
import '../storage/storage_exceptions.dart';

abstract class InspectionRepository {
  List<Inspeccion> obtenerInspecciones();

  void agregarInspeccion(Inspeccion inspeccion);

  DateTime? ultimaInspeccion(String linea);

  Future<List<Inspeccion>> cargarHistorial();

  Future<void> guardarEnHistorial(Inspeccion inspeccion);
}

class CurrentInspectionRepository implements InspectionRepository {
  final InspectionStorage storage;

  const CurrentInspectionRepository({required this.storage});

  @override
  List<Inspeccion> obtenerInspecciones() {
    return storage.obtenerInspeccionesMemoria();
  }

  @override
  void agregarInspeccion(Inspeccion inspeccion) {
    storage.agregarInspeccionMemoria(inspeccion);
  }

  @override
  DateTime? ultimaInspeccion(String linea) {
    return storage.ultimaInspeccionMemoria(linea);
  }

  @override
  Future<List<Inspeccion>> cargarHistorial() async {
    try {
      return await storage.cargarHistorial();
    } on StorageNotFoundException {
      return [];
    }
  }

  @override
  Future<void> guardarEnHistorial(Inspeccion inspeccion) {
    return storage.agregarInspeccionHistorial(inspeccion);
  }
}
