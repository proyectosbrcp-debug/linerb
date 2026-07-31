import '../models/hallazgo_inspeccion.dart';
import '../models/inspeccion.dart';

class InspectionHistoryPage {
  final List<Inspeccion> items;
  final String? nextCursor;
  final bool hasMore;

  const InspectionHistoryPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });
}

abstract class InspectionStorage {
  List<Inspeccion> obtenerInspeccionesMemoria();

  void agregarInspeccionMemoria(Inspeccion inspeccion);

  DateTime? ultimaInspeccionMemoria(String linea);

  Future<List<Inspeccion>> cargarHistorial();

  Future<InspectionHistoryPage> cargarHistorialPage({
    String? cursor,
    int limit = 30,
  }) async {
    final all = await cargarHistorial();
    all.sort((a, b) => b.fecha.compareTo(a.fecha));

    final start = cursor == null ? 0 : int.tryParse(cursor) ?? 0;
    final end = start + limit > all.length ? all.length : start + limit;
    final items = start >= all.length
        ? <Inspeccion>[]
        : all.sublist(start, end);

    return InspectionHistoryPage(
      items: items,
      nextCursor: end >= all.length ? null : end.toString(),
      hasMore: end < all.length,
    );
  }

  Future<void> agregarInspeccionHistorial(Inspeccion inspeccion);

  Future<void> agregarInspeccionCompleta(
    Inspeccion inspeccion,
    List<HallazgoInspeccion> hallazgos,
  );
}
