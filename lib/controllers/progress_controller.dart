import '../core/domain/line_semaforo.dart';
import '../repositories/inspection_repository.dart';

class ProgressController {
  final InspectionRepository inspectionRepository;
  final LineSemaforoRule semaforoRule;
  final DateTime Function() clock;

  const ProgressController({
    required this.inspectionRepository,
    this.semaforoRule = const LineSemaforoRule(),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  DateTime? ultimaInspeccion(String linea) {
    return inspectionRepository.ultimaInspeccion(linea);
  }

  String estadoSemaforo(DateTime? fecha) {
    final result = semaforoRule.evaluate(fecha, clock());

    if (result.daysSinceInspection == null) {
      return "ðŸ”´ Nunca inspeccionada";
    }

    final dias = result.daysSinceInspection!;

    return switch (result.status) {
      LineSemaforoStatus.verde => "ðŸŸ¢ $dias dÃ­as",
      LineSemaforoStatus.amarillo => "ðŸŸ¡ $dias dÃ­as",
      LineSemaforoStatus.rojo => "ðŸ”´ $dias dÃ­as",
    };
  }
}
