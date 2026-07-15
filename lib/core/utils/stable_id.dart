import 'dart:convert';

class StableId {
  const StableId._();

  static String fromParts(String prefix, Iterable<Object?> parts) {
    return '${prefix}_${fnv1a64(parts.join('|'))}';
  }

  static String fromJson(String prefix, String json) {
    return '${prefix}_${fnv1a64(json)}';
  }

  static String fnv1a64(String value) {
    const int fnvPrime = 0x01000193;
    const int offsetBasis = 0x811C9DC5;
    const int mask32 = 0xFFFFFFFF;

    var hash = offsetBasis;

    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * fnvPrime) & mask32;
    }

    return hash.toRadixString(16).padLeft(8, '0');
  }
}
