import 'dart:convert';

import '../models/inspeccion.dart';
import '../services/datos_app.dart';
import '../storage/shared_preferences_storage.dart';

abstract class InspectionRepository {
  List<Inspeccion> obtenerInspecciones();

  void agregarInspeccion(Inspeccion inspeccion);

  DateTime? ultimaInspeccion(String linea);

  Future<List<Inspeccion>> cargarHistorial();

  Future<void> guardarEnHistorial(Inspeccion inspeccion);
}

class CurrentInspectionRepository implements InspectionRepository {
  final SharedPreferencesStorage storage;

  const CurrentInspectionRepository({
    this.storage = const SharedPreferencesStorage(),
  });

  @override
  List<Inspeccion> obtenerInspecciones() {
    return DatosApp.inspecciones;
  }

  @override
  void agregarInspeccion(Inspeccion inspeccion) {
    DatosApp.inspecciones.add(inspeccion);
  }

  @override
  DateTime? ultimaInspeccion(String linea) {
    final registros = DatosApp.inspecciones
        .where((i) => i.linea == linea)
        .toList();

    if (registros.isEmpty) return null;

    registros.sort((a, b) => b.fecha.compareTo(a.fecha));
    return registros.first.fecha;
  }

  @override
  Future<List<Inspeccion>> cargarHistorial() async {
    final prefs = await storage.instance();
    final historialGuardado =
        prefs.getStringList('historial_inspecciones') ?? [];

    return historialGuardado.map((registro) {
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
    }).toList();
  }

  @override
  Future<void> guardarEnHistorial(Inspeccion inspeccion) async {
    final prefs = await storage.instance();
    final historialActual = prefs.getStringList('historial_inspecciones') ?? [];

    final registroJson = jsonEncode({
      'linea': inspeccion.linea,
      'tipoLinea': inspeccion.tipoLinea,
      'responsable': inspeccion.responsable,
      'fecha': inspeccion.fecha.toIso8601String(),
      'estadoLinea': inspeccion.estadoLinea,
      'puntoReferencia': inspeccion.puntoReferencia,
      'observaciones': inspeccion.observaciones,
    });

    historialActual.add(registroJson);

    await prefs.setStringList('historial_inspecciones', historialActual);
  }
}
