import '../core/domain/line_identity.dart';
import '../core/domain/line_semaforo.dart';

enum DashboardLineTypeFilter { all, ramal, troncal, subtroncal }

enum DashboardSemaforoFilter { all, verde, amarillo, rojo }

enum DashboardPeriodFilterType { all, today, last7Days, last30Days, custom }

class DashboardFilter {
  final DashboardLineTypeFilter lineType;
  final DashboardSemaforoFilter semaforo;
  final String? responsible;
  final DashboardPeriodFilterType periodType;
  final DateTime? customStart;
  final DateTime? customEnd;

  const DashboardFilter({
    this.lineType = DashboardLineTypeFilter.all,
    this.semaforo = DashboardSemaforoFilter.all,
    this.responsible,
    this.periodType = DashboardPeriodFilterType.all,
    this.customStart,
    this.customEnd,
  });

  bool get isActive {
    return lineType != DashboardLineTypeFilter.all ||
        semaforo != DashboardSemaforoFilter.all ||
        (responsible != null && responsible!.trim().isNotEmpty) ||
        periodType != DashboardPeriodFilterType.all;
  }

  DashboardFilter copyWith({
    DashboardLineTypeFilter? lineType,
    DashboardSemaforoFilter? semaforo,
    String? responsible,
    bool clearResponsible = false,
    DashboardPeriodFilterType? periodType,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCustomPeriod = false,
  }) {
    return DashboardFilter(
      lineType: lineType ?? this.lineType,
      semaforo: semaforo ?? this.semaforo,
      responsible: clearResponsible ? null : responsible ?? this.responsible,
      periodType: periodType ?? this.periodType,
      customStart: clearCustomPeriod ? null : customStart ?? this.customStart,
      customEnd: clearCustomPeriod ? null : customEnd ?? this.customEnd,
    );
  }

  DashboardFilter clear() {
    return const DashboardFilter();
  }

  DateTimeRangeValue? resolvePeriod(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    return switch (periodType) {
      DashboardPeriodFilterType.all => null,
      DashboardPeriodFilterType.today => DateTimeRangeValue(
        start: today,
        end: today.add(const Duration(days: 1)),
      ),
      DashboardPeriodFilterType.last7Days => DateTimeRangeValue(
        start: today.subtract(const Duration(days: 6)),
        end: today.add(const Duration(days: 1)),
      ),
      DashboardPeriodFilterType.last30Days => DateTimeRangeValue(
        start: today.subtract(const Duration(days: 29)),
        end: today.add(const Duration(days: 1)),
      ),
      DashboardPeriodFilterType.custom =>
        customStart == null
            ? null
            : DateTimeRangeValue(
                start: DateTime(
                  customStart!.year,
                  customStart!.month,
                  customStart!.day,
                ),
                end: DateTime(
                  (customEnd ?? customStart!).year,
                  (customEnd ?? customStart!).month,
                  (customEnd ?? customStart!).day,
                ).add(const Duration(days: 1)),
              ),
    };
  }

  List<String> activeLabels() {
    final labels = <String>[];
    if (lineType != DashboardLineTypeFilter.all) {
      labels.add(_lineTypeLabel(lineType));
    }
    if (semaforo != DashboardSemaforoFilter.all) {
      labels.add(_semaforoLabel(semaforo));
    }
    if (responsible != null && responsible!.trim().isNotEmpty) {
      labels.add('Responsable: ${responsible!.trim()}');
    }
    if (periodType != DashboardPeriodFilterType.all) {
      labels.add(_periodLabel());
    }
    return labels;
  }

  String _periodLabel() {
    return switch (periodType) {
      DashboardPeriodFilterType.all => 'Todo el historial',
      DashboardPeriodFilterType.today => 'Hoy',
      DashboardPeriodFilterType.last7Days => 'Últimos 7 días',
      DashboardPeriodFilterType.last30Days => 'Últimos 30 días',
      DashboardPeriodFilterType.custom => 'Periodo personalizado',
    };
  }

  String _lineTypeLabel(DashboardLineTypeFilter value) {
    return switch (value) {
      DashboardLineTypeFilter.all => 'Todas',
      DashboardLineTypeFilter.ramal => 'Ramal',
      DashboardLineTypeFilter.troncal => 'Troncal',
      DashboardLineTypeFilter.subtroncal => 'Subtroncal',
    };
  }

  String _semaforoLabel(DashboardSemaforoFilter value) {
    return switch (value) {
      DashboardSemaforoFilter.all => 'Todos',
      DashboardSemaforoFilter.verde => 'Verde',
      DashboardSemaforoFilter.amarillo => 'Amarillo',
      DashboardSemaforoFilter.rojo => 'Rojo',
    };
  }
}

class DateTimeRangeValue {
  final DateTime start;
  final DateTime end;

  const DateTimeRangeValue({required this.start, required this.end});

  bool contains(DateTime value) {
    return !value.isBefore(start) && value.isBefore(end);
  }
}

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
  final String? lastResponsible;

  const LineInspectionStatus({
    required this.lineName,
    required this.normalizedKey,
    required this.kind,
    required this.lastInspectionDate,
    required this.inspectionCount,
    required this.semaforoStatus,
    required this.daysSinceInspection,
    this.lastResponsible,
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

class DashboardFindingsDetail {
  final int total;
  final List<FindingCategorySummary> categories;
  final List<DashboardFindingDetailItem> items;
  final String? nextCursor;
  final bool hasMore;

  const DashboardFindingsDetail({
    required this.total,
    required this.categories,
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });
}

class DashboardFindingDetailItem {
  final String id;
  final String category;
  final String lineName;
  final String responsible;
  final DateTime? date;
  final String description;

  const DashboardFindingDetailItem({
    required this.id,
    required this.category,
    required this.lineName,
    required this.responsible,
    required this.date,
    required this.description,
  });
}
