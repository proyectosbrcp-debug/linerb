import '../core/domain/line_identity.dart';
import '../core/domain/line_semaforo.dart';
import '../models/dashboard_models.dart';
import '../repositories/dashboard_repository.dart';

class DashboardController {
  final DashboardRepository repository;
  final DateTime Function() clock;
  final LineIdentityNormalizer lineNormalizer;
  final LineSemaforoRule semaforoRule;

  const DashboardController({
    required this.repository,
    required this.clock,
    this.lineNormalizer = const LineIdentityNormalizer(),
    this.semaforoRule = const LineSemaforoRule(),
  });

  Future<DashboardSummary> loadSummary() async {
    final catalog = await repository.loadCatalog();
    final catalogLines = lineNormalizer.catalogLines(catalog);
    final inspections = await repository.loadValidInspections();
    final findings = await repository.loadValidFindings();
    final invalidRecordsExcluded = await repository.countInvalidRecords();
    final now = clock();

    final inspectionsByLine = <String, List<DashboardInspectionRecord>>{};
    final lineByKey = <String, NormalizedLine>{};

    for (final line in catalogLines) {
      lineByKey[line.normalizedKey] = line;
    }

    for (final inspection in inspections) {
      final normalized = lineNormalizer.normalize(
        inspection.lineName,
        tipoLinea: inspection.tipoLinea,
      );
      inspectionsByLine
          .putIfAbsent(normalized.normalizedKey, () => [])
          .add(inspection);
    }

    final statuses = lineByKey.values.map((line) {
      final lineInspections = inspectionsByLine[line.normalizedKey] ?? [];
      lineInspections.sort((a, b) => b.date.compareTo(a.date));
      final lastInspection = lineInspections.isEmpty
          ? null
          : lineInspections.first.date;
      final semaforo = semaforoRule.evaluate(lastInspection, now);

      return LineInspectionStatus(
        lineName: line.displayName,
        normalizedKey: line.normalizedKey,
        kind: line.kind,
        lastInspectionDate: lastInspection,
        inspectionCount: lineInspections.length,
        semaforoStatus: semaforo.status,
        daysSinceInspection: semaforo.daysSinceInspection,
      );
    }).toList();

    statuses.sort(_prioritizeLine);

    final inspectedLines = statuses
        .where((status) => status.inspectionCount > 0)
        .length;
    final totalCatalogLines = catalogLines.length;
    final neverInspectedLines = statuses
        .where((status) => status.inspectionCount == 0)
        .length;
    final coverage = totalCatalogLines == 0
        ? 0.0
        : (inspectedLines / totalCatalogLines) * 100;

    return DashboardSummary(
      totalCatalogLines: totalCatalogLines,
      inspectedLines: inspectedLines,
      neverInspectedLines: neverInspectedLines,
      coveragePercentage: coverage,
      totalInspections: inspections.length,
      totalFindings: findings.length,
      greenLines: statuses
          .where((status) => status.semaforoStatus == LineSemaforoStatus.verde)
          .length,
      yellowLines: statuses
          .where(
            (status) => status.semaforoStatus == LineSemaforoStatus.amarillo,
          )
          .length,
      redLines: statuses
          .where((status) => status.semaforoStatus == LineSemaforoStatus.rojo)
          .length,
      invalidRecordsExcluded: invalidRecordsExcluded,
      lineStatuses: statuses,
      findingsByCategory: _findingsByCategory(findings),
      dailyInspections: _periods(
        inspections,
        InspectionPeriodType.day,
        _dayStart,
      ),
      weeklyInspections: _periods(
        inspections,
        InspectionPeriodType.week,
        _weekStart,
      ),
      monthlyInspections: _periods(
        inspections,
        InspectionPeriodType.month,
        _monthStart,
      ),
      inspectionsByResponsible: _byResponsible(inspections),
    );
  }

  int _prioritizeLine(LineInspectionStatus a, LineInspectionStatus b) {
    final ar = _riskRank(a);
    final br = _riskRank(b);
    if (ar != br) return br.compareTo(ar);

    final ad = a.daysSinceInspection ?? 999999;
    final bd = b.daysSinceInspection ?? 999999;
    if (ad != bd) return bd.compareTo(ad);

    return a.normalizedKey.compareTo(b.normalizedKey);
  }

  int _riskRank(LineInspectionStatus status) {
    return switch (status.semaforoStatus) {
      LineSemaforoStatus.rojo => 3,
      LineSemaforoStatus.amarillo => 2,
      LineSemaforoStatus.verde => 1,
    };
  }

  List<FindingCategorySummary> _findingsByCategory(
    List<DashboardFindingRecord> findings,
  ) {
    final counts = <String, int>{};
    for (final finding in findings) {
      final category = finding.category.trim().isEmpty
          ? 'Sin categoría'
          : finding.category.trim();
      counts[category] = (counts[category] ?? 0) + 1;
    }

    return counts.entries
        .map(
          (entry) =>
              FindingCategorySummary(category: entry.key, count: entry.value),
        )
        .toList()
      ..sort((a, b) => a.category.compareTo(b.category));
  }

  List<ResponsibleInspectionSummary> _byResponsible(
    List<DashboardInspectionRecord> inspections,
  ) {
    final counts = <String, int>{};
    for (final inspection in inspections) {
      final responsible = inspection.responsible.trim().isEmpty
          ? 'Sin responsable'
          : inspection.responsible.trim();
      counts[responsible] = (counts[responsible] ?? 0) + 1;
    }

    return counts.entries
        .map(
          (entry) => ResponsibleInspectionSummary(
            responsible: entry.key,
            count: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => a.responsible.compareTo(b.responsible));
  }

  List<InspectionPeriodSummary> _periods(
    List<DashboardInspectionRecord> inspections,
    InspectionPeriodType type,
    DateTime Function(DateTime) periodStart,
  ) {
    final counts = <DateTime, int>{};
    for (final inspection in inspections) {
      final period = periodStart(inspection.date);
      counts[period] = (counts[period] ?? 0) + 1;
    }

    return counts.entries
        .map(
          (entry) => InspectionPeriodSummary(
            type: type,
            periodStart: entry.key,
            count: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
  }

  DateTime _dayStart(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _weekStart(DateTime value) {
    final day = _dayStart(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  DateTime _monthStart(DateTime value) {
    return DateTime(value.year, value.month);
  }
}
