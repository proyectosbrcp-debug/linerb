import 'dart:convert';

import '../models/hallazgo_inspeccion.dart';
import '../storage/shared_preferences_storage.dart';

class DraftData {
  final String usuario;
  final String tipoLinea;
  final String seleccionLinea;
  final String responsable;
  final String puntoReferencia;
  final String estadoLinea;
  final List<HallazgoInspeccion> hallazgos;

  const DraftData({
    required this.usuario,
    required this.tipoLinea,
    required this.seleccionLinea,
    required this.responsable,
    required this.puntoReferencia,
    required this.estadoLinea,
    required this.hallazgos,
  });
}

abstract class DraftRepository {
  Future<void> guardarBorrador(DraftData borrador);

  Future<DraftData?> cargarBorrador(String seleccionLinea);

  Future<void> borrarBorrador();
}

class CurrentDraftRepository implements DraftRepository {
  final SharedPreferencesStorage storage;

  const CurrentDraftRepository({
    this.storage = const SharedPreferencesStorage(),
  });

  @override
  Future<void> guardarBorrador(DraftData borrador) async {
    final prefs = await storage.instance();

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

    await prefs.setString('borrador_usuario', borrador.usuario);
    await prefs.setString('borrador_tipoLinea', borrador.tipoLinea);
    await prefs.setString('borrador_seleccionLinea', borrador.seleccionLinea);
    await prefs.setString('borrador_responsable', borrador.responsable);
    await prefs.setString('borrador_puntoReferencia', borrador.puntoReferencia);
    await prefs.setString('borrador_estadoLinea', borrador.estadoLinea);
    await prefs.setStringList('borrador_hallazgos', hallazgosJson);
  }

  @override
  Future<DraftData?> cargarBorrador(String seleccionLinea) async {
    final prefs = await storage.instance();

    final seleccionGuardada = prefs.getString('borrador_seleccionLinea');

    if (seleccionGuardada == null || seleccionGuardada != seleccionLinea) {
      return null;
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
  }

  @override
  Future<void> borrarBorrador() async {
    final prefs = await storage.instance();

    await prefs.remove('borrador_usuario');
    await prefs.remove('borrador_tipoLinea');
    await prefs.remove('borrador_seleccionLinea');
    await prefs.remove('borrador_responsable');
    await prefs.remove('borrador_puntoReferencia');
    await prefs.remove('borrador_estadoLinea');
    await prefs.remove('borrador_hallazgos');
  }
}
