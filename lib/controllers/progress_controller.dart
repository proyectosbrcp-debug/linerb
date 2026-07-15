import '../repositories/inspection_repository.dart';

class ProgressController {
  final InspectionRepository inspectionRepository;

  const ProgressController({required this.inspectionRepository});

  DateTime? ultimaInspeccion(String linea) {
    return inspectionRepository.ultimaInspeccion(linea);
  }

  String estadoSemaforo(DateTime? fecha) {
    if (fecha == null) return "🔴 Nunca inspeccionada";

    final dias = DateTime.now().difference(fecha).inDays;

    if (dias <= 15) return "🟢 $dias días";
    if (dias <= 60) return "🟡 $dias días";
    return "🔴 $dias días";
  }
}
