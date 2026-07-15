import '../models/inspeccion.dart';

abstract class InspectionStorage {
  List<Inspeccion> obtenerInspeccionesMemoria();

  void agregarInspeccionMemoria(Inspeccion inspeccion);

  DateTime? ultimaInspeccionMemoria(String linea);

  Future<List<Inspeccion>> cargarHistorial();

  Future<void> agregarInspeccionHistorial(Inspeccion inspeccion);
}
