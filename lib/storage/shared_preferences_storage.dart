import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalog_data.dart';
import '../models/draft_data.dart';
import '../models/hallazgo_inspeccion.dart';
import '../models/inspeccion.dart';
import '../services/datos_app.dart';
import 'catalog_cache_storage.dart';
import 'draft_storage.dart';
import 'inspection_storage.dart';
import 'storage_exceptions.dart';

class SharedPreferencesStorage
    implements InspectionStorage, DraftStorage, CatalogCacheStorage {
  final List<Inspeccion>? inspeccionesMemoria;

  const SharedPreferencesStorage({this.inspeccionesMemoria});

  List<Inspeccion> get _inspeccionesMemoria =>
      inspeccionesMemoria ?? DatosApp.inspecciones;

  Future<SharedPreferences> instance() {
    return SharedPreferences.getInstance();
  }

  @override
  List<Inspeccion> obtenerInspeccionesMemoria() {
    return _inspeccionesMemoria;
  }

  @override
  void agregarInspeccionMemoria(Inspeccion inspeccion) {
    _inspeccionesMemoria.add(inspeccion);
  }

  @override
  DateTime? ultimaInspeccionMemoria(String linea) {
    final registros = _inspeccionesMemoria
        .where((i) => i.linea == linea)
        .toList();

    if (registros.isEmpty) return null;

    registros.sort((a, b) => b.fecha.compareTo(a.fecha));
    return registros.first.fecha;
  }

  @override
  Future<List<Inspeccion>> cargarHistorial() async {
    try {
      final prefs = await instance();
      final historialGuardado = prefs.getStringList('historial_inspecciones');

      if (historialGuardado == null) {
        throw const StorageNotFoundException(
          'No existe historial_inspecciones',
        );
      }

      return historialGuardado.map(_inspeccionDesdeJson).toList();
    } on StorageException {
      rethrow;
    } on FormatException catch (e) {
      throw StorageCorruptDataException(
        'El historial_inspecciones contiene JSON inválido',
        e,
      );
    } on TypeError catch (e) {
      throw StorageCorruptDataException(
        'El historial_inspecciones tiene una estructura inválida',
        e,
      );
    } catch (e) {
      throw StorageReadException('No se pudo leer historial_inspecciones', e);
    }
  }

  @override
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

  @override
  Future<void> agregarInspeccionHistorial(Inspeccion inspeccion) async {
    try {
      final prefs = await instance();
      final historialActual =
          prefs.getStringList('historial_inspecciones') ?? [];

      historialActual.add(_inspeccionAJson(inspeccion));

      final guardado = await prefs.setStringList(
        'historial_inspecciones',
        historialActual,
      );

      if (!guardado) {
        throw const StorageWriteException(
          'No se pudo guardar historial_inspecciones',
        );
      }
    } on StorageException {
      rethrow;
    } catch (e) {
      throw StorageWriteException(
        'No se pudo escribir historial_inspecciones',
        e,
      );
    }
  }

  @override
  Future<void> agregarInspeccionCompleta(
    Inspeccion inspeccion,
    List<HallazgoInspeccion> hallazgos,
  ) {
    return agregarInspeccionHistorial(inspeccion);
  }

  @override
  Future<void> guardarBorrador(DraftData borrador) async {
    try {
      final prefs = await instance();

      final hallazgosJson = borrador.hallazgos.map((h) {
        return jsonEncode({
          'tipo': h.tipo,
          'detalle': h.detalle,
          'latitud': h.latitud,
          'longitud': h.longitud,
          'descripcion': h.descripcion,
          'foto1Path': h.foto1Path,
          'foto2Path': h.foto2Path,
        });
      }).toList();

      final resultados = await Future.wait([
        prefs.setString('borrador_usuario', borrador.usuario),
        prefs.setString('borrador_tipoLinea', borrador.tipoLinea),
        prefs.setString('borrador_seleccionLinea', borrador.seleccionLinea),
        prefs.setString('borrador_responsable', borrador.responsable),
        prefs.setString('borrador_puntoReferencia', borrador.puntoReferencia),
        prefs.setString('borrador_estadoLinea', borrador.estadoLinea),
        prefs.setStringList('borrador_hallazgos', hallazgosJson),
      ]);

      if (resultados.any((guardado) => !guardado)) {
        throw const StorageWriteException('No se pudo guardar el borrador');
      }
    } on StorageException {
      rethrow;
    } catch (e) {
      throw StorageWriteException('No se pudo escribir el borrador', e);
    }
  }

  @override
  Future<DraftData> cargarBorrador(String seleccionLinea) async {
    try {
      final prefs = await instance();
      final seleccionGuardada = prefs.getString('borrador_seleccionLinea');

      if (seleccionGuardada == null || seleccionGuardada != seleccionLinea) {
        throw const StorageNotFoundException(
          'No existe borrador para la línea',
        );
      }

      final hallazgosJson = prefs.getStringList('borrador_hallazgos') ?? [];
      final hallazgos = <HallazgoInspeccion>[];

      for (final item in hallazgosJson) {
        final data = jsonDecode(item);

        hallazgos.add(
          HallazgoInspeccion(
            tipo: data['tipo'] ?? '',
            detalle: data['detalle'] ?? '',
            latitud: data['latitud'] ?? '',
            longitud: data['longitud'] ?? '',
            descripcion: data['descripcion'] ?? '',
            foto1Path: data['foto1Path'],
            foto2Path: data['foto2Path'],
          ),
        );
      }

      return DraftData(
        usuario: prefs.getString('borrador_usuario') ?? '',
        tipoLinea: prefs.getString('borrador_tipoLinea') ?? '',
        seleccionLinea: seleccionGuardada,
        responsable: prefs.getString('borrador_responsable') ?? '',
        puntoReferencia: prefs.getString('borrador_puntoReferencia') ?? '',
        estadoLinea: prefs.getString('borrador_estadoLinea') ?? 'Operativa',
        hallazgos: hallazgos,
      );
    } on StorageException {
      rethrow;
    } on FormatException catch (e) {
      throw StorageCorruptDataException(
        'El borrador contiene JSON inválido',
        e,
      );
    } on TypeError catch (e) {
      throw StorageCorruptDataException(
        'El borrador tiene una estructura inválida',
        e,
      );
    } catch (e) {
      throw StorageReadException('No se pudo leer el borrador', e);
    }
  }

  @override
  Future<void> borrarBorrador() async {
    try {
      final prefs = await instance();

      final resultados = await Future.wait([
        prefs.remove('borrador_usuario'),
        prefs.remove('borrador_tipoLinea'),
        prefs.remove('borrador_seleccionLinea'),
        prefs.remove('borrador_responsable'),
        prefs.remove('borrador_puntoReferencia'),
        prefs.remove('borrador_estadoLinea'),
        prefs.remove('borrador_hallazgos'),
      ]);

      if (resultados.any((borrado) => !borrado)) {
        throw const StorageWriteException('No se pudo borrar el borrador');
      }
    } on StorageException {
      rethrow;
    } catch (e) {
      throw StorageWriteException('No se pudo borrar el borrador', e);
    }
  }

  @override
  Future<CatalogData> cargarCatalogosCache() async {
    try {
      final prefs = await instance();
      final troncalesCache = prefs.getString('json_troncales_cache');
      final ramalesCache = prefs.getString('json_ramales_cache');

      if (troncalesCache == null || ramalesCache == null) {
        throw const StorageNotFoundException('No existe cache de catálogos');
      }

      return CatalogData(
        troncalesJson: Map<String, dynamic>.from(json.decode(troncalesCache)),
        ramalesJson: List<String>.from(json.decode(ramalesCache)['ramales']),
      );
    } on StorageException {
      rethrow;
    } on FormatException catch (e) {
      throw StorageCorruptDataException(
        'El cache de catálogos contiene JSON inválido',
        e,
      );
    } on TypeError catch (e) {
      throw StorageCorruptDataException(
        'El cache de catálogos tiene una estructura inválida',
        e,
      );
    } catch (e) {
      throw StorageReadException('No se pudo leer cache de catálogos', e);
    }
  }

  @override
  Future<void> guardarCatalogosCache({
    required String troncalesJson,
    required String ramalesJson,
  }) async {
    try {
      final prefs = await instance();

      final resultados = await Future.wait([
        prefs.setString('json_troncales_cache', troncalesJson),
        prefs.setString('json_ramales_cache', ramalesJson),
      ]);

      if (resultados.any((guardado) => !guardado)) {
        throw const StorageWriteException(
          'No se pudo guardar cache de catálogos',
        );
      }
    } on StorageException {
      rethrow;
    } catch (e) {
      throw StorageWriteException('No se pudo escribir cache de catálogos', e);
    }
  }

  Inspeccion _inspeccionDesdeJson(String registro) {
    final data = jsonDecode(registro);

    return Inspeccion(
      linea: data['linea'],
      tipoLinea: data['tipoLinea'],
      responsable: data['responsable'],
      fecha: DateTime.parse(data['fecha']),
      estadoLinea: data['estadoLinea'],
      puntoReferencia: data['puntoReferencia'],
      observaciones: data['observaciones'],
    );
  }

  String _inspeccionAJson(Inspeccion inspeccion) {
    return jsonEncode({
      'linea': inspeccion.linea,
      'tipoLinea': inspeccion.tipoLinea,
      'responsable': inspeccion.responsable,
      'fecha': inspeccion.fecha.toIso8601String(),
      'estadoLinea': inspeccion.estadoLinea,
      'puntoReferencia': inspeccion.puntoReferencia,
      'observaciones': inspeccion.observaciones,
    });
  }
}
