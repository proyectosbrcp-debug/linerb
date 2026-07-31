import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/constants/catalog_urls.dart';
import '../core/logging/app_logger.dart';
import '../models/catalog_data.dart';
import '../storage/catalog_cache_storage.dart';
import '../storage/storage_exceptions.dart';

export '../models/catalog_data.dart';

abstract class CatalogRepository {
  Future<CatalogData?> cargarCatalogos();
}

class CurrentCatalogRepository implements CatalogRepository {
  final CatalogCacheStorage storage;

  const CurrentCatalogRepository({required this.storage});

  @override
  Future<CatalogData?> cargarCatalogos() async {
    try {
      AppLogger.info('Consultando catálogos remotos');

      final troncalesResponse = await http.get(Uri.parse(troncalesCatalogUrl));
      final ramalesResponse = await http.get(Uri.parse(ramalesCatalogUrl));

      if (troncalesResponse.statusCode == 200 &&
          ramalesResponse.statusCode == 200) {
        await storage.guardarCatalogosCache(
          troncalesJson: troncalesResponse.body,
          ramalesJson: ramalesResponse.body,
        );

        AppLogger.info('Catálogos remotos cargados y guardados en cache');

        return CatalogData(
          troncalesJson: Map<String, dynamic>.from(
            json.decode(troncalesResponse.body),
          ),
          ramalesJson: List<String>.from(
            json.decode(ramalesResponse.body)['ramales'],
          ),
        );
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'No se pudo cargar catálogos remotos',
        error,
        stackTrace,
      );
    }

    try {
      AppLogger.info('Cargando catálogos desde cache local');

      final catalogos = await storage.cargarCatalogosCache();

      AppLogger.info('Catálogos cargados desde cache local');

      return catalogos;
    } on StorageNotFoundException {
      // Mantiene el comportamiento previo: si no hay cache, intenta assets.
    } catch (error, stackTrace) {
      AppLogger.warning('No se pudo cargar cache local', error, stackTrace);
    }

    try {
      AppLogger.info('Cargando catálogos internos');

      final String troncalesData = await rootBundle.loadString(
        'assets/data/troncales.json',
      );

      final String ramalesData = await rootBundle.loadString(
        'assets/data/ramales.json',
      );

      AppLogger.info('Catálogos internos cargados');

      return CatalogData(
        troncalesJson: Map<String, dynamic>.from(json.decode(troncalesData)),
        ramalesJson: List<String>.from(json.decode(ramalesData)['ramales']),
      );
    } catch (error, stackTrace) {
      AppLogger.error('No se pudo cargar ningún catálogo', error, stackTrace);
    }

    return null;
  }
}
