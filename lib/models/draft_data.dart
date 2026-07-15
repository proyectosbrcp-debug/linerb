import 'hallazgo_inspeccion.dart';

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
