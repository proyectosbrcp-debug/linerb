import 'package:flutter/material.dart';

import '../../controllers/dashboard_controller.dart';
import '../../core/constants/query_page_config.dart';
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
  final ScrollController _scrollController = ScrollController();
  DashboardFindingsDetail? _detail;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String? _nextCursor;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    try {
      final detail = await widget.controller.loadFindingsDetail(
        filter: widget.initialFilter,
        limit: QueryPageConfig.dashboardFindingsPageSize,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _nextCursor = detail.nextCursor;
        _isLoading = false;
        _hasError = false;
      });
    } catch (error, stackTrace) {
      AppLogger.warning(
        'No se pudo cargar el detalle de hallazgos',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMore() async {
    final current = _detail;
    if (_isLoadingMore || current == null || !current.hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final next = await widget.controller.loadFindingsDetail(
        filter: widget.initialFilter,
        cursor: _nextCursor,
        limit: QueryPageConfig.dashboardFindingsPageSize,
      );
      if (!mounted) return;
      setState(() {
        _detail = DashboardFindingsDetail(
          total: next.total,
          categories: next.categories,
          items: [...current.items, ...next.items],
          nextCursor: next.nextCursor,
          hasMore: next.hasMore,
        );
        _nextCursor = next.nextCursor;
        _isLoadingMore = false;
      });
    } catch (error, stackTrace) {
      AppLogger.warning(
        'No se pudo cargar mas detalle de hallazgos',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 300) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError || detail == null
          ? const _GenericError()
          : detail.items.isEmpty
          ? const _NoResults()
          : ListView(
              controller: _scrollController,
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
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
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
              'AgrupaciÃ³n por categorÃ­a',
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
        ? 'Sin descripciÃ³n disponible'
        : item.description.trim();

    return Card(
      child: ListTile(
        title: Text(
          item.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'LÃ­nea: ${item.lineName}\n'
          'Fecha: $date\n'
          'Responsable: ${item.responsible}\n'
          'DescripciÃ³n: $description',
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
          'No se pudo cargar la informaciÃ³n. Intente nuevamente mÃ¡s tarde.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
