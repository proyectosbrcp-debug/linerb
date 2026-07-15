import '../models/inspeccion.dart';
import '../repositories/inspection_repository.dart';

class HistoryController {
  final InspectionRepository inspectionRepository;
  List<Inspeccion> inspecciones = [];

  HistoryController({InspectionRepository? inspectionRepository})
    : inspectionRepository =
          inspectionRepository ?? const CurrentInspectionRepository();

  Future<List<Inspeccion>> cargarHistorial() async {
    inspecciones = await inspectionRepository.cargarHistorial();
    return inspecciones;
  }
}
