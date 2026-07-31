import 'package:flutter/material.dart';

import '../../controllers/dashboard_controller.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/domain/line_identity.dart';
import '../../core/domain/line_semaforo.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/date_utils.dart';
import '../../models/dashboard_models.dart';
import '../../models/sync_status_snapshot.dart';
import '../../widgets/sync_status_indicator.dart';
import 'dashboard_findings_detail_page.dart';
import 'dashboard_priority_detail_page.dart';

class DashboardPage extends StatefulWidget {
  final DashboardController? controller;

  const DashboardPage({super.key, this.controller});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _controller;
  late Future<DashboardSummary> _summaryFuture;
  DashboardFilter _filter = const DashboardFilter();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AppDependencies.dashboardController();
    _summaryFuture = _loadSummary();
  }

  Future<DashboardSummary> _loadSummary() async {
    try {
      return await _controller.loadSummary(filter: _filter);
    } catch (error, stackTrace) {
      AppLogger.warning('No se pudo cargar el dashboard', error, stackTrace);
      rethrow;
    }
  }

  void _updateFilter(DashboardFilter filter) {
    setState(() {
      _filter = filter;
      _summaryFuture = _loadSummary();
    });
  }

  void _clearFilters() {
    _updateFilter(_filter.clear());
  }

  Future<void> _pickCustomStart() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _filter.customStart ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (!mounted || selected == null) return;
    _updateFilter(
      _filter.copyWith(
        periodType: DashboardPeriodFilterType.custom,
        customStart: selected,
      ),
    );
  }

  Future<void> _pickCustomEnd() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _filter.customEnd ?? _filter.customStart ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (!mounted || selected == null) return;
    _updateFilter(
      _filter.copyWith(
        periodType: DashboardPeriodFilterType.custom,
        customEnd: selected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [SyncStatusIndicator()],
      ),
      body: FutureBuilder<DashboardSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _DashboardLoading();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const _DashboardError();
          }

          final summary = snapshot.data!;
          if (!_filter.isActive && _isEmpty(summary)) {
            return const _DashboardEmpty();
          }

          return _DashboardContent(
            summary: summary,
            filter: _filter,
            controller: _controller,
            onFilterChanged: _updateFilter,
            onClearFilters: _clearFilters,
            onPickCustomStart: _pickCustomStart,
            onPickCustomEnd: _pickCustomEnd,
          );
        },
      ),
    );
  }

  bool _isEmpty(DashboardSummary summary) {
    return summary.totalCatalogLines == 0 &&
        summary.totalInspections == 0 &&
        summary.totalFindings == 0;
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Cargando dashboard...'),
        ],
      ),
    );
  }
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No hay datos disponibles para el dashboard',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No se pudo cargar el dashboard. Intente nuevamente más tarde.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardSummary summary;
  final DashboardFilter filter;
  final DashboardController controller;
  final ValueChanged<DashboardFilter> onFilterChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onPickCustomStart;
  final VoidCallback onPickCustomEnd;

  const _DashboardContent({
    required this.summary,
    required this.filter,
    required this.controller,
    required this.onFilterChanged,
    required this.onClearFilters,
    required this.onPickCustomStart,
    required this.onPickCustomEnd,
  });

  @override
  Widget build(BuildContext context) {
    final priorityLines = summary.lineStatuses.take(10).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DashboardSyncSummary(),
          const SizedBox(height: 12),
          _DashboardFilters(
            filter: filter,
            responsibles: _responsibles(),
            onFilterChanged: onFilterChanged,
            onClearFilters: onClearFilters,
            onPickCustomStart: onPickCustomStart,
            onPickCustomEnd: onPickCustomEnd,
          ),
          const SizedBox(height: 12),
          Text(
            'Resultados filtrados: ${summary.lineStatuses.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (filter.isActive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: filter
                    .activeLabels()
                    .map((label) => Chip(label: Text(label)))
                    .toList(),
              ),
            ),
          if (_hasNoResults()) ...[
            const SizedBox(height: 18),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Sin resultados para los filtros aplicados',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 18),
            const _SectionTitle(title: 'Resumen general'),
            _MetricGrid(
              children: [
                _MetricCard(
                  title: 'Cobertura',
                  value: '${summary.coveragePercentage.toStringAsFixed(1)}%',
                  icon: Icons.pie_chart,
                ),
                _MetricCard(
                  title: 'Líneas inspeccionadas',
                  value: '${summary.inspectedLines}',
                  icon: Icons.check_circle,
                ),
                _MetricCard(
                  title: 'Líneas pendientes',
                  value: '${summary.neverInspectedLines}',
                  icon: Icons.schedule,
                ),
                _MetricCard(
                  title: 'Total inspecciones',
                  value: '${summary.totalInspections}',
                  icon: Icons.assignment_turned_in,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SectionTitle(title: 'Semáforo de líneas'),
            _SemaforoGrid(
              children: [
                _SemaforoCard(
                  title: 'Verdes',
                  value: summary.greenLines,
                  color: Colors.green,
                ),
                _SemaforoCard(
                  title: 'Amarillas',
                  value: summary.yellowLines,
                  color: Colors.amber,
                ),
                _SemaforoCard(
                  title: 'Rojas',
                  value: summary.redLines,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SectionTitle(title: 'Prioridad de inspección'),
            Card(
              child: Column(
                children: [
                  if (priorityLines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay líneas para priorizar'),
                    )
                  else
                    for (final status in priorityLines)
                      _PriorityRow(status: status),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DashboardPriorityDetailPage(
                      controller: controller,
                      initialFilter: filter,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('Ver prioridad completa'),
            ),
            const SizedBox(height: 18),
            const _SectionTitle(title: 'Hallazgos y responsables'),
            _MetricCard(
              title: 'Total hallazgos',
              value: '${summary.totalFindings}',
              icon: Icons.report_problem,
            ),
            const SizedBox(height: 10),
            _SummaryList(
              title: 'Principales categorías de hallazgo',
              emptyText: 'Sin hallazgos registrados',
              items: summary.findingsByCategory
                  .take(3)
                  .map((item) => '${item.category}: ${item.count}')
                  .toList(),
            ),
            const SizedBox(height: 10),
            _SummaryList(
              title: 'Inspecciones por responsable',
              emptyText: 'Sin inspecciones registradas',
              items: summary.inspectionsByResponsible
                  .take(3)
                  .map((item) => '${item.responsible}: ${item.count}')
                  .toList(),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DashboardFindingsDetailPage(
                      controller: controller,
                      initialFilter: filter,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.report),
              label: const Text('Ver detalle de hallazgos'),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _responsibles() {
    final values =
        summary.inspectionsByResponsible
            .map((item) => item.responsible)
            .where((item) => item.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final selected = filter.responsible;
    if (selected != null && selected.trim().isNotEmpty) {
      values.add(selected);
    }

    return values.toSet().toList()..sort();
  }

  bool _hasNoResults() {
    return filter.isActive &&
        summary.lineStatuses.isEmpty &&
        summary.totalInspections == 0 &&
        summary.totalFindings == 0;
  }
}

class _DashboardSyncSummary extends StatelessWidget {
  const _DashboardSyncSummary();

  @override
  Widget build(BuildContext context) {
    final coordinator = AppDependencies.automaticSyncCoordinator;
    return StreamBuilder<SyncStatusSnapshot>(
      stream: coordinator.stream,
      initialData: coordinator.snapshot,
      builder: (context, snapshot) {
        final status = snapshot.data ?? const SyncStatusSnapshot.initial();
        final lastUpdate = status.lastSuccessfulSyncAt == null
            ? 'No disponible'
            : fechaCorta(status.lastSuccessfulSyncAt!);
        final warning =
            status.pendingCount > 0 ||
            status.failedCount > 0 ||
            status.conflictCount > 0 ||
            !status.connectivityAvailable;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estado de sincronización',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(syncStatusLabel(status)),
                Text('Última actualización: $lastUpdate'),
                Text('Pendientes: ${status.pendingCount}'),
                if (warning)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Los datos pueden estar desactualizados.',
                      style: TextStyle(color: Color(0xFFB71C1C)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardFilters extends StatelessWidget {
  final DashboardFilter filter;
  final List<String> responsibles;
  final ValueChanged<DashboardFilter> onFilterChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onPickCustomStart;
  final VoidCallback onPickCustomEnd;

  const _DashboardFilters({
    required this.filter,
    required this.responsibles,
    required this.onFilterChanged,
    required this.onClearFilters,
    required this.onPickCustomStart,
    required this.onPickCustomEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filtros',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<DashboardLineTypeFilter>(
              initialValue: filter.lineType,
              decoration: const InputDecoration(
                labelText: 'Tipo de línea',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: DashboardLineTypeFilter.all,
                  child: Text('Todas'),
                ),
                DropdownMenuItem(
                  value: DashboardLineTypeFilter.ramal,
                  child: Text('Ramal'),
                ),
                DropdownMenuItem(
                  value: DashboardLineTypeFilter.troncal,
                  child: Text('Troncal'),
                ),
                DropdownMenuItem(
                  value: DashboardLineTypeFilter.subtroncal,
                  child: Text('Subtroncal'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                onFilterChanged(filter.copyWith(lineType: value));
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<DashboardSemaforoFilter>(
              initialValue: filter.semaforo,
              decoration: const InputDecoration(
                labelText: 'Semáforo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: DashboardSemaforoFilter.all,
                  child: Text('Todos'),
                ),
                DropdownMenuItem(
                  value: DashboardSemaforoFilter.verde,
                  child: Text('Verde'),
                ),
                DropdownMenuItem(
                  value: DashboardSemaforoFilter.amarillo,
                  child: Text('Amarillo'),
                ),
                DropdownMenuItem(
                  value: DashboardSemaforoFilter.rojo,
                  child: Text('Rojo'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                onFilterChanged(filter.copyWith(semaforo: value));
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: filter.responsible,
              decoration: const InputDecoration(
                labelText: 'Responsable',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(value: '', child: Text('Todos')),
                for (final responsible in responsibles)
                  DropdownMenuItem(
                    value: responsible,
                    child: Text(responsible),
                  ),
              ],
              onChanged: (value) {
                onFilterChanged(
                  value == null || value.isEmpty
                      ? filter.copyWith(clearResponsible: true)
                      : filter.copyWith(responsible: value),
                );
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<DashboardPeriodFilterType>(
              initialValue: filter.periodType,
              decoration: const InputDecoration(
                labelText: 'Periodo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: DashboardPeriodFilterType.all,
                  child: Text('Todo el historial'),
                ),
                DropdownMenuItem(
                  value: DashboardPeriodFilterType.today,
                  child: Text('Hoy'),
                ),
                DropdownMenuItem(
                  value: DashboardPeriodFilterType.last7Days,
                  child: Text('Últimos 7 días'),
                ),
                DropdownMenuItem(
                  value: DashboardPeriodFilterType.last30Days,
                  child: Text('Últimos 30 días'),
                ),
                DropdownMenuItem(
                  value: DashboardPeriodFilterType.custom,
                  child: Text('Personalizado'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                onFilterChanged(filter.copyWith(periodType: value));
              },
            ),
            if (filter.periodType == DashboardPeriodFilterType.custom) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPickCustomStart,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      filter.customStart == null
                          ? 'Fecha inicial'
                          : fechaCorta(filter.customStart!),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPickCustomEnd,
                    icon: const Icon(Icons.event),
                    label: Text(
                      filter.customEnd == null
                          ? 'Fecha final'
                          : fechaCorta(filter.customEnd!),
                    ),
                  ),
                ],
              ),
            ],
            if (filter.isActive) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear),
                label: const Text('Limpiar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D47A1),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _MetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth < 360 ? 1 : 2,
          childAspectRatio: constraints.maxWidth < 360 ? 4 : 2.4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: children,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0D47A1), size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemaforoGrid extends StatelessWidget {
  final List<Widget> children;

  const _SemaforoGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth < 360 ? 1 : 3,
          childAspectRatio: constraints.maxWidth < 360 ? 4 : 1.35,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: children,
        );
      },
    );
  }
}

class _SemaforoCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;

  const _SemaforoCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  final LineInspectionStatus status;

  const _PriorityRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final lastInspection = status.lastInspectionDate == null
        ? 'Nunca inspeccionada'
        : fechaCorta(status.lastInspectionDate!);

    return Column(
      children: [
        ListTile(
          dense: true,
          leading: Icon(
            Icons.circle,
            color: _semaforoColor(status.semaforoStatus),
            size: 16,
          ),
          title: Text(
            status.lineName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${_kindLabel(status.kind)} • $lastInspection'),
          trailing: Text(
            _semaforoLabel(status.semaforoStatus),
            style: TextStyle(
              color: _semaforoColor(status.semaforoStatus),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Color _semaforoColor(LineSemaforoStatus status) {
    return switch (status) {
      LineSemaforoStatus.verde => Colors.green,
      LineSemaforoStatus.amarillo => Colors.amber,
      LineSemaforoStatus.rojo => Colors.red,
    };
  }

  String _semaforoLabel(LineSemaforoStatus status) {
    return switch (status) {
      LineSemaforoStatus.verde => 'Verde',
      LineSemaforoStatus.amarillo => 'Amarillo',
      LineSemaforoStatus.rojo => 'Rojo',
    };
  }

  String _kindLabel(LineKind kind) {
    return switch (kind) {
      LineKind.ramal => 'Ramal',
      LineKind.troncal => 'Troncal',
      LineKind.subtroncal => 'Subtroncal',
      LineKind.desconocida => 'Sin clasificar',
    };
  }
}

class _SummaryList extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<String> items;

  const _SummaryList({
    required this.title,
    required this.emptyText,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(emptyText)
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(item),
                ),
          ],
        ),
      ),
    );
  }
}
