import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/constants/catalog_urls.dart';
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
      print("========== CONSULTANDO FIREBASE ==========");

      final troncalesResponse = await http.get(Uri.parse(troncalesCatalogUrl));

      final ramalesResponse = await http.get(Uri.parse(ramalesCatalogUrl));

      if (troncalesResponse.statusCode == 200 &&
          ramalesResponse.statusCode == 200) {
        await storage.guardarCatalogosCache(
          troncalesJson: troncalesResponse.body,
          ramalesJson: ramalesResponse.body,
        );

        print("✅ JSON FIREBASE CARGADO Y GUARDADO EN CACHE");

        return CatalogData(
          troncalesJson: Map<String, dynamic>.from(
            json.decode(troncalesResponse.body),
          ),
          ramalesJson: List<String>.from(
            json.decode(ramalesResponse.body)['ramales'],
          ),
        );
      }
    } catch (e) {
      print("⚠ No se pudo cargar desde Firebase");
      print(e);
    }

    try {
      print("========== CARGANDO CACHE LOCAL ==========");

      final catalogos = await storage.cargarCatalogosCache();

      print("✅ JSON CARGADO DESDE CACHE LOCAL");

      return catalogos;
    } on StorageNotFoundException {
      // Mantiene el comportamiento previo: si no hay cache, intenta assets.
    } catch (e) {
      print("⚠ No se pudo cargar cache local");
      print(e);
    }

    try {
      print("========== CARGANDO JSON INTERNO ==========");

      final String troncalesData = await rootBundle.loadString(
        'assets/data/troncales.json',
      );

      final String ramalesData = await rootBundle.loadString(
        'assets/data/ramales.json',
      );

      print("✅ JSON INTERNO CARGADO");

      return CatalogData(
        troncalesJson: Map<String, dynamic>.from(json.decode(troncalesData)),
        ramalesJson: List<String>.from(json.decode(ramalesData)['ramales']),
      );
    } catch (e) {
      print("❌ ERROR TOTAL CARGANDO JSON");
      print(e);
    }

    return null;
  }
}
