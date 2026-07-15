import '../../models/catalog_data.dart';

enum LineKind { ramal, troncal, subtroncal, desconocida }

class NormalizedLine {
  final String originalName;
  final String displayName;
  final String normalizedKey;
  final LineKind kind;

  const NormalizedLine({
    required this.originalName,
    required this.displayName,
    required this.normalizedKey,
    required this.kind,
  });
}

class LineIdentityNormalizer {
  const LineIdentityNormalizer();

  NormalizedLine normalize(String value, {String? tipoLinea}) {
    final collapsed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    final normalizedSlash = collapsed.replaceAll(RegExp(r'\s*/\s*'), ' / ');
    final key = normalizedSlash.toUpperCase();

    return NormalizedLine(
      originalName: value,
      displayName: normalizedSlash,
      normalizedKey: key,
      kind: _kindFor(key, tipoLinea),
    );
  }

  List<NormalizedLine> catalogLines(CatalogData? catalogData) {
    if (catalogData == null) return const [];

    final linesByKey = <String, NormalizedLine>{};

    catalogData.troncalesJson.forEach((troncal, subs) {
      final subList = List<String>.from(subs as Iterable);
      for (final sub in subList) {
        final line = normalize('$troncal / $sub', tipoLinea: 'Troncal');
        linesByKey.putIfAbsent(line.normalizedKey, () => line);
      }
    });

    for (final ramal in catalogData.ramalesJson) {
      final line = normalize(ramal, tipoLinea: 'Ramal');
      linesByKey.putIfAbsent(line.normalizedKey, () => line);
    }

    return linesByKey.values.toList();
  }

  LineKind _kindFor(String key, String? tipoLinea) {
    final type = tipoLinea?.trim().toUpperCase();

    if (type == 'RAMAL' || key.startsWith('RAMAL')) {
      return LineKind.ramal;
    }

    if (key.contains('/')) {
      return LineKind.subtroncal;
    }

    if (type == 'TRONCAL' || key.startsWith('TRONCAL')) {
      return LineKind.troncal;
    }

    return LineKind.desconocida;
  }
}
