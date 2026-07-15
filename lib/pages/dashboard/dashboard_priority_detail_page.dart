import 'package:flutter/material.dart';

import '../../controllers/dashboard_controller.dart';
import '../../core/domain/line_identity.dart';
import '../../core/domain/line_semaforo.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/date_utils.dart';
import '../../models/dashboard_models.dart';

class DashboardPriorityDetailPage extends StatefulWidget {
  final DashboardController controller;
  final DashboardFilter initialFilter;

  const DashboardPriorityDetailPage({
    super.key,
    required this.controller,
    this.initialFilter = const DashboardFilter(),
  });

  @override
  State<DashboardPriorityDetailPage> createState() =>
      _DashboardPriorityDetailPageState();
}

class _DashboardPriorityDetailPageState
    extends State<DashboardPriorityDetailPage> {
  late DashboardFilter _filter;
  String _searchQuery = '';
  late Future<List<LineInspectionStatus>> _future;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _future = _load();
  }

  Future<List<LineInspectionStatus>> _load() async {
    try {
      return await widget.controller.loadPriorityDetails(
        filter: _filter,
        searchQuery: _searchQuery,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'No se pudo cargar el detalle de prioridad',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
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
          'Prioridad de inspección',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _PriorityFilters(
            filter: _filter,
            onSearchChanged: (value) {
              _searchQuery = value;
              _reload();
            },
            onFilterChanged: (filter) {
              _filter = filter;
              _reload();
            },
          ),
          Expanded(
            child: FutureBuilder<List<LineInspectionStatus>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return const _GenericError();
                }

                final lines = snapshot.data!;
                if (lines.isEmpty) {
                  return const _NoResults();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: lines.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _PriorityDetailCard(status: lines[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityFilters extends StatelessWidget {
  final DashboardFilter filter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DashboardFilter> onFilterChanged;

  const _PriorityFilters({
    required this.filter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar línea',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<DashboardLineTypeFilter>(
              initialValue: filter.lineType,
              decoration: const InputDecoration(
                labelText: 'Tipo',
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
          ],
        ),
      ),
    );
  }
}

class _PriorityDetailCard extends StatelessWidget {
  final LineInspectionStatus status;

  const _PriorityDetailCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final lastInspection = status.lastInspectionDate == null
        ? 'Nunca inspeccionada'
        : fechaCorta(status.lastInspectionDate!);
    final days = status.daysSinceInspection == null
        ? 'Sin inspección previa'
        : '${status.daysSinceInspection} días';
    final responsible = status.lastResponsible?.trim();

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.circle,
          color: _semaforoColor(status.semaforoStatus),
          size: 16,
        ),
        title: Text(
          status.lineName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_kindLabel(status.kind)}\n'
          'Última inspección: $lastInspection\n'
          'Días transcurridos: $days\n'
          'Responsable: ${responsible == null || responsible.isEmpty ? 'No disponible' : responsible}',
        ),
        isThreeLine: true,
        trailing: Text(
          _semaforoLabel(status.semaforoStatus),
          style: TextStyle(
            color: _semaforoColor(status.semaforoStatus),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Sin resultados'));
  }
}

class _GenericError extends StatelessWidget {
  const _GenericError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No se pudo cargar la información. Intente nuevamente más tarde.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
