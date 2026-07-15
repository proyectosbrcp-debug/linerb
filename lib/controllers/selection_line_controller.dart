import '../repositories/catalog_repository.dart';

class SelectionLineController {
  final CatalogRepository catalogRepository;
  CatalogData? catalogData;

  SelectionLineController({required this.catalogRepository});

  Future<CatalogData?> cargarCatalogos() async {
    catalogData = await catalogRepository.cargarCatalogos();
    return catalogData;
  }

  List<String> todasLasLineas(
    Map<String, dynamic> troncalesJson,
    List<String> ramalesJson,
  ) {
    final List<String> lineas = [];

    troncalesJson.forEach((troncal, subs) {
      for (final sub in subs) {
        lineas.add('$troncal / $sub');
      }
    });

    for (final ramal in ramalesJson) {
      lineas.add(ramal);
    }

    return lineas;
  }
}
