import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/constants/catalog_urls.dart';
import '../storage/shared_preferences_storage.dart';

class CatalogData {
  final Map<String, dynamic> troncalesJson;
  final List<String> ramalesJson;

  const CatalogData({required this.troncalesJson, required this.ramalesJson});
}

abstract class CatalogRepository {
  Future<CatalogData?> cargarCatalogos();
}

class CurrentCatalogRepository implements CatalogRepository {
  final SharedPreferencesStorage storage;

  const CurrentCatalogRepository({
    this.storage = const SharedPreferencesStorage(),
  });

  @override
  Future<CatalogData?> cargarCatalogos() async {
    final prefs = await storage.instance();

    try {
      print("========== CONSULTANDO FIREBASE ==========");

      final troncalesResponse = await http.get(Uri.parse(troncalesCatalogUrl));

      final ramalesResponse = await http.get(Uri.parse(ramalesCatalogUrl));

      if (troncalesResponse.statusCode == 200 &&
          ramalesResponse.statusCode == 200) {
        await prefs.setString('json_troncales_cache', troncalesResponse.body);
        await prefs.setString('json_ramales_cache', ramalesResponse.body);

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

      final troncalesCache = prefs.getString('json_troncales_cache');
      final ramalesCache = prefs.getString('json_ramales_cache');

      if (troncalesCache != null && ramalesCache != null) {
        print("✅ JSON CARGADO DESDE CACHE LOCAL");

        return CatalogData(
          troncalesJson: Map<String, dynamic>.from(json.decode(troncalesCache)),
          ramalesJson: List<String>.from(json.decode(ramalesCache)['ramales']),
        );
      }
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
