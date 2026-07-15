import '../core/domain/line_identity.dart';
import '../core/domain/line_semaforo.dart';

class DashboardSummary {
  final int totalCatalogLines;
  final int inspectedLines;
  final int neverInspectedLines;
  final double coveragePercentage;
  final int totalInspections;
  final int totalFindings;
  final int greenLines;
  final int yellowLines;
  final int redLines;
  final int invalidRecordsExcluded;
  final List<LineInspectionStatus> lineStatuses;
  final List<FindingCategorySummary> findingsByCategory;
  final List<InspectionPeriodSummary> dailyInspections;
  final List<InspectionPeriodSummary> weeklyInspections;
  final List<InspectionPeriodSummary> monthlyInspections;
  final List<ResponsibleInspectionSummary> inspectionsByResponsible;

  const DashboardSummary({
    required this.totalCatalogLines,
    required this.inspectedLines,
    required this.neverInspectedLines,
    required this.coveragePercentage,
    required this.totalInspections,
    required this.totalFindings,
    required this.greenLines,
    required this.yellowLines,
    required this.redLines,
    required this.invalidRecordsExcluded,
    required this.lineStatuses,
    required this.findingsByCategory,
    required this.dailyInspections,
    required this.weeklyInspections,
    required this.monthlyInspections,
    required this.inspectionsByResponsible,
  });
}

class LineInspectionStatus {
  final String lineName;
  final String normalizedKey;
  final LineKind kind;
  final DateTime? lastInspectionDate;
  final int inspectionCount;
  final LineSemaforoStatus semaforoStatus;
  final int? daysSinceInspection;

  const LineInspectionStatus({
    required this.lineName,
    required this.normalizedKey,
    required this.kind,
    required this.lastInspectionDate,
    required this.inspectionCount,
    required this.semaforoStatus,
    required this.daysSinceInspection,
  });
}

class FindingCategorySummary {
  final String category;
  final int count;

  const FindingCategorySummary({required this.category, required this.count});
}

enum InspectionPeriodType { day, week, month }

class InspectionPeriodSummary {
  final InspectionPeriodType type;
  final DateTime periodStart;
  final int count;

  const InspectionPeriodSummary({
    required this.type,
    required this.periodStart,
    required this.count,
  });
}

class ResponsibleInspectionSummary {
  final String responsible;
  final int count;

  const ResponsibleInspectionSummary({
    required this.responsible,
    required this.count,
  });
}
