enum LineSemaforoStatus { verde, amarillo, rojo }

class LineSemaforoResult {
  final LineSemaforoStatus status;
  final int? daysSinceInspection;

  const LineSemaforoResult({
    required this.status,
    required this.daysSinceInspection,
  });
}

class LineSemaforoRule {
  const LineSemaforoRule();

  LineSemaforoResult evaluate(DateTime? lastInspection, DateTime now) {
    if (lastInspection == null) {
      return const LineSemaforoResult(
        status: LineSemaforoStatus.rojo,
        daysSinceInspection: null,
      );
    }

    final days = now.difference(lastInspection).inDays;

    if (days <= 15) {
      return LineSemaforoResult(
        status: LineSemaforoStatus.verde,
        daysSinceInspection: days,
      );
    }

    if (days <= 60) {
      return LineSemaforoResult(
        status: LineSemaforoStatus.amarillo,
        daysSinceInspection: days,
      );
    }

    return LineSemaforoResult(
      status: LineSemaforoStatus.rojo,
      daysSinceInspection: days,
    );
  }
}
