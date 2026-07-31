import '../models/inspeccion.dart';
import '../core/constants/query_page_config.dart';
import '../repositories/inspection_repository.dart';
import '../storage/inspection_storage.dart';

class HistoryController {
  final InspectionRepository inspectionRepository;
  List<Inspeccion> inspecciones = [];
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingPage = false;

  HistoryController({required this.inspectionRepository});

  bool get hasMore => _hasMore;

  bool get isLoadingPage => _isLoadingPage;

  Future<List<Inspeccion>> cargarHistorial() async {
    inspecciones = await inspectionRepository.cargarHistorial();
    return inspecciones;
  }

  Future<InspectionHistoryPage> cargarPrimeraPagina({
    int limit = QueryPageConfig.historyPageSize,
  }) async {
    _nextCursor = null;
    _hasMore = true;
    inspecciones = [];
    return cargarSiguientePagina(limit: limit);
  }

  Future<InspectionHistoryPage> cargarSiguientePagina({
    int limit = QueryPageConfig.historyPageSize,
  }) async {
    if (_isLoadingPage || !_hasMore) {
      return InspectionHistoryPage(
        items: const [],
        nextCursor: _nextCursor,
        hasMore: _hasMore,
      );
    }

    _isLoadingPage = true;
    try {
      final page = await inspectionRepository.cargarHistorialPage(
        cursor: _nextCursor,
        limit: limit,
      );
      inspecciones = [...inspecciones, ...page.items];
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      return page;
    } finally {
      _isLoadingPage = false;
    }
  }
}
