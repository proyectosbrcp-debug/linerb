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

  Future<DashboardSummary> loadSummary({
    DashboardFilter filter = const DashboardFilter(),
  }) async {
    final catalog = await repository.loadCatalog();
    final catalogLines = lineNormalizer.catalogLines(catalog);
    final inspections = await repository.loadValidInspections();
    final findings = await repository.loadValidFindings();
    final invalidRecordsExcluded = await repository.countInvalidRecords();
    final now = clock();

    final statuses = _lineStatuses(catalogLines, inspections, now);
    final filteredStatuses = _filterStatuses(
      statuses,
      inspections,
      filter,
      now,
    );
    final allowedLineKeys = filteredStatuses
        .map((status) => status.normalizedKey)
        .toSet();
    final filteredInspections = inspections.where((inspection) {
      final key = _inspectionKey(inspection);
      return allowedLineKeys.contains(key) &&
          _matchesInspectionFilters(inspection, filter, now);
    }).toList();
    final filteredFindings = findings.where((finding) {
      final key = _findingKey(finding);
      return allowedLineKeys.contains(key) &&
          _matchesFindingFilters(finding, filter, now);
    }).toList();

    return _buildSummary(
      statuses: filteredStatuses,
      inspections: filteredInspections,
      findings: filteredFindings,
      invalidRecordsExcluded: invalidRecordsExcluded,
    );
  }

  Future<List<LineInspectionStatus>> loadPriorityDetails({
    DashboardFilter filter = const DashboardFilter(),
    String searchQuery = '',
  }) async {
    final summary = await loadSummary(filter: filter);
    final query = searchQuery.trim().toUpperCase();
    if (query.isEmpty) return summary.lineStatuses;

    return summary.lineStatuses
        .where((status) => status.lineName.toUpperCase().contains(query))
        .toList();
  }

  Future<DashboardFindingsDetail> loadFindingsDetail({
    DashboardFilter filter = const DashboardFilter(),
  }) async {
    final catalog = await repository.loadCatalog();
    final catalogLines = lineNormalizer.catalogLines(catalog);
    final inspections = await repository.loadValidInspections();
    final findings = await repository.loadValidFindings();
    final now = clock();
    final statuses = _filterStatuses(
      _lineStatuses(catalogLines, inspections, now),
      inspections,
      filter,
      now,
    );
    final allowedLineKeys = statuses
        .map((status) => status.normalizedKey)
        .toSet();
    final filteredFindings = findings.where((finding) {
      final key = _findingKey(finding);
      return allowedLineKeys.contains(key) &&
          _matchesFindingFilters(finding, filter, now);
    }).toList();

    return DashboardFindingsDetail(
      total: filteredFindings.length,
      categories: _findingsByCategory(filteredFindings),
      items: filteredFindings.map(_findingDetailItem).toList(),
    );
  }

  List<LineInspectionStatus> _lineStatuses(
    List<NormalizedLine> catalogLines,
    List<DashboardInspectionRecord> inspections,
    DateTime now,
  ) {
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
      final lastResponsible = lineInspections.isEmpty
          ? null
          : lineInspections.first.responsible;
      final semaforo = semaforoRule.evaluate(lastInspection, now);

      return LineInspectionStatus(
        lineName: line.displayName,
        normalizedKey: line.normalizedKey,
        kind: line.kind,
        lastInspectionDate: lastInspection,
        inspectionCount: lineInspections.length,
        semaforoStatus: semaforo.status,
        daysSinceInspection: semaforo.daysSinceInspection,
        lastResponsible: lastResponsible,
      );
    }).toList();

    statuses.sort(_prioritizeLine);
    return statuses;
  }

  DashboardSummary _buildSummary({
    required List<LineInspectionStatus> statuses,
    required List<DashboardInspectionRecord> inspections,
    required List<DashboardFindingRecord> findings,
    required int invalidRecordsExcluded,
  }) {
    final inspectedLineKeys = inspections.map(_inspectionKey).toSet();

    final inspectedLines = statuses
        .where((status) => inspectedLineKeys.contains(status.normalizedKey))
        .length;
    final totalCatalogLines = statuses.length;
    final neverInspectedLines = statuses
        .where((status) => !inspectedLineKeys.contains(status.normalizedKey))
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

  List<LineInspectionStatus> _filterStatuses(
    List<LineInspectionStatus> statuses,
    List<DashboardInspectionRecord> inspections,
    DashboardFilter filter,
    DateTime now,
  ) {
    final matchingInspectionKeys = inspections
        .where(
          (inspection) => _matchesInspectionFilters(inspection, filter, now),
        )
        .map(_inspectionKey)
        .toSet();
    final shouldRequireMatchingInspection =
        (filter.responsible != null && filter.responsible!.trim().isNotEmpty) ||
        filter.periodType != DashboardPeriodFilterType.all;

    return statuses.where((status) {
      if (!_matchesLineType(status.kind, filter.lineType)) return false;
      if (!_matchesSemaforo(status.semaforoStatus, filter.semaforo)) {
        return false;
      }
      if (shouldRequireMatchingInspection &&
          !matchingInspectionKeys.contains(status.normalizedKey)) {
        return false;
      }
      return true;
    }).toList();
  }

  bool _matchesInspectionFilters(
    DashboardInspectionRecord inspection,
    DashboardFilter filter,
    DateTime now,
  ) {
    final responsible = filter.responsible?.trim();
    if (responsible != null &&
        responsible.isNotEmpty &&
        inspection.responsible.trim() != responsible) {
      return false;
    }

    final period = filter.resolvePeriod(now);
    if (period != null && !period.contains(inspection.date)) {
      return false;
    }

    return true;
  }

  bool _matchesFindingFilters(
    DashboardFindingRecord finding,
    DashboardFilter filter,
    DateTime now,
  ) {
    final responsible = filter.responsible?.trim();
    if (responsible != null &&
        responsible.isNotEmpty &&
        finding.responsible.trim() != responsible) {
      return false;
    }

    final period = filter.resolvePeriod(now);
    final findingDate = finding.date;
    if (period != null &&
        (findingDate == null || !period.contains(findingDate))) {
      return false;
    }

    return true;
  }

  bool _matchesLineType(LineKind kind, DashboardLineTypeFilter filter) {
    return switch (filter) {
      DashboardLineTypeFilter.all => true,
      DashboardLineTypeFilter.ramal => kind == LineKind.ramal,
      DashboardLineTypeFilter.troncal => kind == LineKind.troncal,
      DashboardLineTypeFilter.subtroncal => kind == LineKind.subtroncal,
    };
  }

  bool _matchesSemaforo(
    LineSemaforoStatus status,
    DashboardSemaforoFilter filter,
  ) {
    return switch (filter) {
      DashboardSemaforoFilter.all => true,
      DashboardSemaforoFilter.verde => status == LineSemaforoStatus.verde,
      DashboardSemaforoFilter.amarillo => status == LineSemaforoStatus.amarillo,
      DashboardSemaforoFilter.rojo => status == LineSemaforoStatus.rojo,
    };
  }

  String _inspectionKey(DashboardInspectionRecord inspection) {
    return lineNormalizer
        .normalize(inspection.lineName, tipoLinea: inspection.tipoLinea)
        .normalizedKey;
  }

  String _findingKey(DashboardFindingRecord finding) {
    return lineNormalizer
        .normalize(finding.lineName, tipoLinea: finding.tipoLinea)
        .normalizedKey;
  }

  DashboardFindingDetailItem _findingDetailItem(
    DashboardFindingRecord finding,
  ) {
    return DashboardFindingDetailItem(
      id: finding.id,
      category: finding.category,
      lineName: finding.lineName,
      responsible: finding.responsible,
      date: finding.date,
      description: finding.description,
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
