class HallazgoInspeccion {
  final String tipo;
  final String detalle;
  final String latitud;
  final String longitud;
  final String descripcion;
  final String? foto1Path;
  final String? foto2Path;

  HallazgoInspeccion({
    required this.tipo,
    required this.detalle,
    required this.latitud,
    required this.longitud,
    required this.descripcion,
    this.foto1Path,
    this.foto2Path,
  });

  @override
  String toString() {
    final titulo = detalle.isEmpty ? tipo : "$tipo - $detalle";
    return "$titulo\nCoordenadas: $latitud, $longitud\nFotos: FOTO 1  FOTO 2\nDescripción: $descripcion";
  }
}
