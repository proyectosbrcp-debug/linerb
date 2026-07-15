import '../models/catalog_data.dart';

abstract class CatalogCacheStorage {
  Future<CatalogData> cargarCatalogosCache();

  Future<void> guardarCatalogosCache({
    required String troncalesJson,
    required String ramalesJson,
  });
}
