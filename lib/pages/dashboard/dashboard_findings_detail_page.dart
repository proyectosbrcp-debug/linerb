import 'package:flutter/material.dart';

import '../../controllers/dashboard_controller.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/date_utils.dart';
import '../../models/dashboard_models.dart';

class DashboardFindingsDetailPage extends StatefulWidget {
  final DashboardController controller;
  final DashboardFilter initialFilter;

  const DashboardFindingsDetailPage({
    super.key,
    required this.controller,
    this.initialFilter = const DashboardFilter(),
  });

  @override
  State<DashboardFindingsDetailPage> createState() =>
      _DashboardFindingsDetailPageState();
}

class _DashboardFindingsDetailPageState
    extends State<DashboardFindingsDetailPage> {
  late final Future<DashboardFindingsDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashboardFindingsDetail> _load() async {
    try {
      return await widget.controller.loadFindingsDetail(
        filter: widget.initialFilter,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'No se pudo cargar el detalle de hallazgos',
        error,
        stackTrace,
      );
      rethrow;
    }
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
          'Detalle de hallazgos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<DashboardFindingsDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const _GenericError();
          }

          final detail = snapshot.data!;
          if (detail.items.isEmpty) {
            return const _NoResults();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Total filtrado: ${detail.total}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _CategorySummary(categories: detail.categories),
              const SizedBox(height: 10),
              for (final item in detail.items) _FindingCard(item: item),
            ],
          );
        },
      ),
    );
  }
}

class _CategorySummary extends StatelessWidget {
  final List<FindingCategorySummary> categories;

  const _CategorySummary({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agrupación por categoría',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${category.category}: ${category.count}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  final DashboardFindingDetailItem item;

  const _FindingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final date = item.date == null ? 'Sin fecha' : fechaCorta(item.date!);
    final description = item.description.trim().isEmpty
        ? 'Sin descripción disponible'
        : item.description.trim();

    return Card(
      child: ListTile(
        title: Text(
          item.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Línea: ${item.lineName}\n'
          'Fecha: $date\n'
          'Responsable: ${item.responsible}\n'
          'Descripción: $description',
        ),
        isThreeLine: true,
      ),
    );
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
